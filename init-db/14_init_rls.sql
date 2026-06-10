-- =============================================================================
-- 14_init_rls.sql
-- Row Level Security (RLS) — Protección de datos personales
-- Ley 21.719 Chile / GDPR-compatible
--
-- CÓMO FUNCIONA:
--   NestJS inyecta en cada transacción:
--     SET LOCAL app.user_uuid = '<uuid>';
--     SET LOCAL app.org_uuid  = '<uuid>';
--
--   Las políticas leen esas variables con:
--     current_setting('app.user_uuid', true)   -- true = no error si no está seteada
--
--   El usuario de conexión del pool (ej: "seis_app") tiene acceso normal.
--   Un rol de solo-lectura sin bypass puede usarse para reportes.
--
-- IMPORTANTE:
--   - SET LOCAL solo vive dentro de la transacción → seguro con connection pool
--   - SET SESSION NO usar → contamina conexiones del pool entre requests
--   - El rol que hace BYPASS es el superusuario de migraciones (ej: postgres)
-- =============================================================================

SET search_path TO public, core, factura;

-- ---------------------------------------------------------------------------
-- 0. ROL DE APLICACIÓN (no superusuario, sin bypass RLS)
--    Ajustar al nombre real del usuario de conexión del pool de ms-core.
-- ---------------------------------------------------------------------------
-- Si ya existe el rol, este bloque no hace nada:
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'seis_app') THEN
        CREATE ROLE seis_app LOGIN;
    END IF;
END
$$;

-- El rol de aplicación NO tiene BYPASSRLS — las políticas se aplican siempre
-- El superusuario (postgres) y el rol de migraciones SÍ tienen bypass implícito

-- ---------------------------------------------------------------------------
-- 1. FUNCIÓN AUXILIAR: obtener user_uuid del contexto de la transacción
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.current_user_uuid()
RETURNS UUID LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN current_setting('app.user_uuid', true)::UUID;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION core.current_org_uuid()
RETURNS UUID LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN current_setting('app.org_uuid', true)::UUID;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. RLS: core.contacto
--    Política: el usuario solo ve/modifica su propio contacto.
--    Admins y migraciones bypasean (superusuario).
-- ---------------------------------------------------------------------------

ALTER TABLE core.contacto ENABLE ROW LEVEL SECURITY;
-- Los superusuarios y el rol de migraciones (postgres) pasan siempre
ALTER TABLE core.contacto FORCE ROW LEVEL SECURITY;

-- SELECT / UPDATE / DELETE: solo tu propio contacto
DROP POLICY IF EXISTS pol_contacto_owner ON core.contacto;
CREATE POLICY pol_contacto_owner ON core.contacto
    FOR ALL
    USING (
        -- El contacto pertenece al usuario autenticado
        contacto_id IN (
            SELECT u.contacto_id
            FROM core.usuario u
            WHERE u.usuario_uuid = core.current_user_uuid()
        )
        -- O el contexto no está seteado (migraciones / seeds sin SET LOCAL)
        OR core.current_user_uuid() IS NULL
    );

-- ---------------------------------------------------------------------------
-- 3. RLS: core.cuenta_bancaria
--    Política: solo la org propietaria de la cuenta puede verla/modificarla.
-- ---------------------------------------------------------------------------

ALTER TABLE core.cuenta_bancaria ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.cuenta_bancaria FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_cuenta_bancaria_org ON core.cuenta_bancaria;
CREATE POLICY pol_cuenta_bancaria_org ON core.cuenta_bancaria
    FOR ALL
    USING (
        organizacion_id IN (
            SELECT o.organizacion_id
            FROM core.organizacion o
            WHERE o.organizacion_uuid = core.current_org_uuid()
        )
        OR core.current_org_uuid() IS NULL
    );

-- ---------------------------------------------------------------------------
-- 4. RLS: factura.factura
--    Política: CEDENTE ve sus propias facturas.
--              FINANCIADORA ve facturas PUBLICADAS/OFERTADAS/FINANCIADAS.
--              La vista de marketplace ya filtra por status, RLS agrega capa extra.
-- ---------------------------------------------------------------------------

ALTER TABLE factura.factura ENABLE ROW LEVEL SECURITY;
ALTER TABLE factura.factura FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_factura_cedente ON factura.factura;
CREATE POLICY pol_factura_cedente ON factura.factura
    FOR ALL
    USING (
        -- El emisor siempre ve sus propias facturas
        organizacion_id = core.current_org_uuid()
        -- Las financiadoras ven facturas públicas (PUBLICADA, OFERTADA, FINANCIADA)
        OR (
            status IN ('PUBLICADA', 'OFERTADA', 'FINANCIADA', 'PAGADA')
            AND core.current_org_uuid() IS NOT NULL
        )
        -- Sin contexto (migraciones)
        OR core.current_org_uuid() IS NULL
    );

-- ---------------------------------------------------------------------------
-- 5. RLS: core.organizacion_credencial_sii
--    Política más estricta: SOLO la propia org puede ver su credencial.
--    Ni otras organizaciones ni roles de lectura pueden acceder.
-- ---------------------------------------------------------------------------

ALTER TABLE core.organizacion_credencial_sii ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.organizacion_credencial_sii FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pol_credencial_sii_owner ON core.organizacion_credencial_sii;
CREATE POLICY pol_credencial_sii_owner ON core.organizacion_credencial_sii
    FOR ALL
    USING (
        organizacion_id IN (
            SELECT o.organizacion_id
            FROM core.organizacion o
            WHERE o.organizacion_uuid = core.current_org_uuid()
        )
        -- Sin contexto solo pasa si no hay ningún uuid seteado (migraciones)
        OR core.current_org_uuid() IS NULL
    );

-- ---------------------------------------------------------------------------
-- 6. VISTAS ENMASCARADAS (datos sensibles con display seguro)
--    NestJS usa estas vistas en lugar de las tablas directas para
--    respuestas de API que van al frontend.
-- ---------------------------------------------------------------------------

-- RUT enmascarado: 12.345.***-*
CREATE OR REPLACE VIEW core.vw_contacto_seguro AS
SELECT
    contacto_id,
    nombres,
    apellido_paterno,
    apellido_materno,
    correo,
    -- Celular: muestra solo los últimos 4 dígitos
    CASE
        WHEN celular IS NOT NULL
        THEN regexp_replace(celular, '(\d)(?=\d{4})', '*', 'g')
        ELSE NULL
    END AS celular,
    tipo_documento,
    -- Número de documento enmascarado: ***-**** excepto últimos 3 chars
    CASE
        WHEN numero_documento IS NOT NULL
        THEN overlay(numero_documento placing repeat('*', length(numero_documento) - 3)
             from 1 for length(numero_documento) - 3)
        ELSE NULL
    END AS numero_documento_enmascarado,
    pais_emision,
    -- Fecha de nacimiento: solo año (no exponer edad exacta en listados)
    EXTRACT(YEAR FROM fecha_nacimiento)::INT AS anio_nacimiento,
    activo,
    created_at,
    updated_at
FROM core.contacto;

-- Cuenta bancaria enmascarada
CREATE OR REPLACE VIEW core.vw_cuenta_bancaria_segura AS
SELECT
    cuenta_id,
    organizacion_id,
    nombre_titular,
    -- RUT titular enmascarado
    CASE
        WHEN rut_titular IS NOT NULL
        THEN overlay(rut_titular placing '****' from 1 for length(rut_titular) - 3)
        ELSE NULL
    END AS rut_titular_enmascarado,
    banco,
    -- Número de cuenta: solo últimos 4 dígitos
    CASE
        WHEN numero IS NOT NULL
        THEN '****' || right(numero, 4)
        ELSE NULL
    END AS numero_enmascarado,
    correo_contacto
FROM core.cuenta_bancaria;

-- Factura con RUT deudor enmascarado (para marketplace público)
CREATE OR REPLACE VIEW factura.vw_factura_marketplace AS
SELECT
    f.id,
    f.factura_numero,
    f.deudor_nombre,
    -- RUT deudor enmascarado para marketplace
    overlay(f.deudor_rut placing '****' from 1 for length(f.deudor_rut) - 3)
        AS deudor_rut_enmascarado,
    f.monto_total,
    f.fecha_vencimiento,
    f.status,
    f.created_at
FROM factura.factura f
WHERE f.status IN ('PUBLICADA', 'OFERTADA');

-- ---------------------------------------------------------------------------
-- FIN 14_init_rls.sql
-- ---------------------------------------------------------------------------
