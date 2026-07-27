-- =============================================================================
-- 002_fix_monto_total_decimal.sql
-- Corregir tipo de dato monto_total: VARCHAR(255) → DECIMAL(15,2)
-- Prioridad: 🔴 CRÍTICA
-- Estimación: 2 horas (incluye testing de vistas)
-- Riesgo: MEDIO (requiere actualizar vistas y funciones)
-- =============================================================================

\echo '========================================='
\echo 'Migrando monto_total: VARCHAR → DECIMAL'
\echo '========================================='

-- ============================================================================
-- PASO 1: Análisis previo
-- ============================================================================

\echo ''
\echo 'Paso 1: Analizando datos actuales...'

SELECT 
    COUNT(*) AS total_facturas,
    COUNT(CASE WHEN monto_total ~ '^[0-9]+\.?[0-9]*$' THEN 1 END) AS montos_validos,
    COUNT(CASE WHEN monto_total !~ '^[0-9]+\.?[0-9]*$' THEN 1 END) AS montos_invalidos,
    MIN(LENGTH(monto_total)) AS min_length,
    MAX(LENGTH(monto_total)) AS max_length
FROM factura.factura;

\echo ''
\echo 'Ejemplos de valores inválidos (si existen):'
SELECT id, monto_total 
FROM factura.factura 
WHERE monto_total !~ '^[0-9]+\.?[0-9]*$' 
LIMIT 5;

-- ============================================================================
-- PASO 2: Backup de seguridad
-- ============================================================================

\echo ''
\echo 'Paso 2: Creando tabla de backup...'

BEGIN;

CREATE TABLE IF NOT EXISTS factura.factura_backup_monto_total_20260726 AS
SELECT id, monto_total AS monto_total_original, now() AS backup_timestamp
FROM factura.factura;

\echo 'Backup creado en factura.factura_backup_monto_total_20260726'

-- ============================================================================
-- PASO 3: Agregar nueva columna con tipo correcto
-- ============================================================================

\echo ''
\echo 'Paso 3: Agregando columna monto_total_decimal...'

ALTER TABLE factura.factura 
ADD COLUMN IF NOT EXISTS monto_total_decimal DECIMAL(15,2);

-- ============================================================================
-- PASO 4: Migrar datos
-- ============================================================================

\echo ''
\echo 'Paso 4: Migrando datos (limpiar caracteres no numéricos)...'

-- Convertir datos: eliminar caracteres no numéricos excepto punto decimal
UPDATE factura.factura 
SET monto_total_decimal = NULLIF(
    REGEXP_REPLACE(monto_total, '[^\d.]', '', 'g'), 
    ''
)::DECIMAL(15,2)
WHERE monto_total IS NOT NULL;

-- Verificar conversión
\echo ''
\echo 'Verificando conversión...'

SELECT 
    COUNT(*) AS total_facturas,
    COUNT(monto_total_decimal) AS montos_migrados,
    COUNT(*) - COUNT(monto_total_decimal) AS montos_null
FROM factura.factura;

-- Listar casos donde la conversión falló (NULL inesperado)
\echo ''
\echo 'Casos con conversión fallida (revisar manualmente):'
SELECT id, monto_total, monto_total_decimal 
FROM factura.factura 
WHERE monto_total IS NOT NULL AND monto_total_decimal IS NULL
LIMIT 10;

-- ============================================================================
-- PASO 5: Actualizar vistas dependientes
-- ============================================================================

\echo ''
\echo 'Paso 5: Actualizando vistas dependientes...'

-- Vista: vw_facturas_publicadas_con_datos
DROP VIEW IF EXISTS factura.vw_facturas_publicadas_con_datos CASCADE;
CREATE OR REPLACE VIEW factura.vw_facturas_publicadas_con_datos AS
SELECT
    fct.id AS factura_id,
    fct.factura_numero AS folio,
    fct.deudor_nombre,
    fct.deudor_rut,
    fct.monto_total_decimal AS monto_total,  -- ✅ ACTUALIZADO
    o.razon_social AS cliente_nombre,
    o.rut AS cliente_rut,
    u.usuario_uuid AS gestor_id,
    CONCAT(c.nombres, ' ', c.apellido_paterno, ' ', c.apellido_materno) AS gestor_nombre,
    fct.fecha_vencimiento,
    fct.status,
    fct.created_at,
    fct.updated_at
FROM
    factura.factura fct
    JOIN core.organizacion o ON o.organizacion_uuid = fct.organizacion_id
    LEFT JOIN core.usuario u ON fct.gestor_usuario_uuid = u.usuario_uuid
    LEFT JOIN core.contacto c ON u.contacto_id = c.contacto_id
WHERE
    fct.status = 'PUBLICADA';

\echo 'Vista vw_facturas_publicadas_con_datos actualizada.'

-- Vista: vw_factura_ofertas_resumen (no referencia directamente monto_total, pero verificar)
-- Esta vista ya usa monto_total desde la tabla, se actualizará automáticamente

-- Vista: vw_facturas_publicadas_para_matching
DROP VIEW IF EXISTS factura.vw_facturas_publicadas_para_matching CASCADE;
CREATE OR REPLACE VIEW factura.vw_facturas_publicadas_para_matching AS
SELECT
    f.id AS factura_id,
    f.organizacion_id,
    f.deudor_rut,
    f.factura_numero,
    f.monto_total_decimal AS monto_total,  -- ✅ ACTUALIZADO
    f.fecha_vencimiento,
    f.created_at,
    COALESCE(r.total_operaciones, 0) AS matches_previos,
    r.usuario_id AS ejecutivo_relacionado,
    r.financiadora_id AS financiadora_relacionada,
    COALESCE(r.score_fidelidad, 0) AS score_fidelidad_relacion
FROM factura.factura f
LEFT JOIN factura.relaciones_preferidas r
    ON r.organizacion_id = f.organizacion_id
WHERE f.status = 'PUBLICADA';

\echo 'Vista vw_facturas_publicadas_para_matching actualizada.'

-- ============================================================================
-- PASO 6: Actualizar funciones dependientes
-- ============================================================================

\echo ''
\echo 'Paso 6: Actualizando funciones dependientes...'

-- Función: factura.obtener_facturas_accesibles
-- (Líneas 338-436 de 08_init_invoice.sql)
DROP FUNCTION IF EXISTS factura.obtener_facturas_accesibles(UUID, UUID) CASCADE;

CREATE OR REPLACE FUNCTION factura.obtener_facturas_accesibles(
    p_usuario_uuid UUID,
    p_organizacion_id UUID
) RETURNS TABLE (
    factura_id UUID,
    folio VARCHAR,
    deudor_nombre VARCHAR,
    deudor_rut VARCHAR,
    monto_total DECIMAL,  -- ✅ ACTUALIZADO: VARCHAR → DECIMAL
    cliente_nombre VARCHAR,
    cliente_rut VARCHAR,
    gestor_id UUID,
    gestor_nombre VARCHAR,
    fecha_vencimiento DATE,
    status VARCHAR,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    tiene_permiso BOOLEAN,
    url_factura VARCHAR,
    correlation_id UUID,
    adjuntos JSONB
) AS $$
BEGIN
    -- Verificar que el usuario sea ejecutivo de una financiadora
    IF NOT permisos.validar_usuario_ejecutivo_financiadora(p_usuario_uuid) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        fct.id,
        fct.factura_numero,
        fct.deudor_nombre,
        fct.deudor_rut,
        fct.monto_total_decimal,  -- ✅ ACTUALIZADO
        o.razon_social,
        o.rut,
        u.usuario_uuid,
        CONCAT(c.nombres, ' ', c.apellido_paterno, ' ', c.apellido_materno),
        fct.fecha_vencimiento,
        fct.status::VARCHAR,
        fct.created_at,
        fct.updated_at,
        permisos.check_access('FACTURA', fct.id, p_usuario_uuid, 'VIEW', p_organizacion_id) AS tiene_permiso,
        COALESCE(mv_principal.url_path::VARCHAR, '') AS url_factura,
        fct.correlation_id,
        adj_json.adjuntos
    FROM
        factura.factura fct
        JOIN core.organizacion o ON o.organizacion_uuid = fct.organizacion_id
        LEFT JOIN core.usuario u ON fct.gestor_usuario_uuid = u.usuario_uuid
        LEFT JOIN core.contacto c ON u.contacto_id = c.contacto_id
        LEFT JOIN LATERAL (
            SELECT mv.url_path
            FROM factura.factura_adjuntos fa
            JOIN media.media_variants mv ON mv.asset_id = fa.asset_id
            WHERE fa.factura_id = fct.id AND fa.es_principal = TRUE
            ORDER BY mv.created_at DESC NULLS LAST
            LIMIT 1
        ) mv_principal ON TRUE
        LEFT JOIN LATERAL (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id',           fa.id,
                    'asset_id',     fa.asset_id,
                    'tipo',         fa.tipo,
                    'es_principal', fa.es_principal,
                    'orden',        fa.orden,
                    'descripcion',  fa.descripcion,
                    'url_path',     mv_adj.url_path
                ) ORDER BY fa.orden ASC, fa.created_at ASC
            ) AS adjuntos
            FROM factura.factura_adjuntos fa
            LEFT JOIN LATERAL (
                SELECT mv2.url_path
                FROM media.media_variants mv2
                WHERE mv2.asset_id = fa.asset_id
                ORDER BY mv2.created_at DESC NULLS LAST
                LIMIT 1
            ) mv_adj ON TRUE
            WHERE fa.factura_id = fct.id
        ) adj_json ON TRUE
    WHERE
        fct.status = 'PUBLICADA'
        AND (
            permisos.check_access('FACTURA', fct.id, p_usuario_uuid, 'VIEW', p_organizacion_id)
            OR
            EXISTS (
                SELECT 1 FROM permisos.resource_owner ro
                WHERE ro.resource_type = 'FACTURA'
                  AND ro.resource_id = fct.id
                  AND ro.owner_usuario_uuid = p_usuario_uuid
            )
        )
    ORDER BY fct.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

\echo 'Función factura.obtener_facturas_accesibles actualizada.'

-- ============================================================================
-- PASO 7: Actualizar vistas de permisos
-- ============================================================================

\echo ''
\echo 'Paso 7: Actualizando vistas de schema permisos...'

-- Vista: permisos.vw_facturas_publicadas_ofertadas_base
DROP VIEW IF EXISTS permisos.vw_facturas_publicadas_ofertadas_base CASCADE;
CREATE OR REPLACE VIEW permisos.vw_facturas_publicadas_ofertadas_base AS
SELECT
    f.id AS factura_id,
    f.organizacion_id AS cedente_org_id,
    org.razon_social AS cedente_razon_social,
    CONCAT(org.rut,'-',org.dv) AS cedente_rut,
    f.deudor_nombre,
    f.deudor_rut,
    f.factura_numero,
    f.monto_total_decimal AS monto_total,  -- ✅ ACTUALIZADO
    f.fecha_vencimiento,
    f.status::VARCHAR AS factura_status,
    f.created_at,
    f.updated_at,
    COALESCE(r.total_ofertas, 0) AS total_ofertas,
    COALESCE(r.ofertas_enviadas, 0) AS ofertas_enviadas,
    COALESCE(r.ofertas_revisadas, 0) AS ofertas_revisadas,
    COALESCE(r.ofertas_aceptadas, 0) AS ofertas_aceptadas,
    COALESCE(r.ofertas_rechazadas, 0) AS ofertas_rechazadas,
    r.mejor_tasa,
    r.mejor_monto_oferta,
    r.ultima_actualizacion_oferta,
    (COALESCE(r.total_ofertas, 0) > 0) AS esta_ofertada,
    mv.url_path,
    f.gestor_usuario_uuid as gestor_uuid,
    u.username as username,
    f.correlation_id,
    adj.adjuntos
FROM factura.factura f
JOIN core.organizacion org
    ON org.organizacion_uuid = f.organizacion_id
LEFT JOIN factura.vw_factura_ofertas_resumen r
    ON r.factura_id = f.id
LEFT JOIN core.usuario u
    ON u.usuario_uuid = f.gestor_usuario_uuid
LEFT JOIN LATERAL (
    SELECT mv.url_path
    FROM factura.factura_adjuntos fa
    JOIN media.media_variants mv ON mv.asset_id = fa.asset_id
    WHERE fa.factura_id = f.id AND fa.es_principal = TRUE
    ORDER BY mv.created_at DESC NULLS LAST
    LIMIT 1
) mv ON TRUE
LEFT JOIN LATERAL (
    SELECT jsonb_agg(
        jsonb_build_object(
            'id',           fa.id,
            'asset_id',     fa.asset_id,
            'tipo',         fa.tipo,
            'es_principal', fa.es_principal,
            'orden',        fa.orden,
            'descripcion',  fa.descripcion,
            'url_path',     mv_adj.url_path
        ) ORDER BY fa.orden ASC, fa.created_at ASC
    ) AS adjuntos
    FROM factura.factura_adjuntos fa
    LEFT JOIN LATERAL (
        SELECT mv2.url_path
        FROM media.media_variants mv2
        WHERE mv2.asset_id = fa.asset_id
        ORDER BY mv2.created_at DESC NULLS LAST
        LIMIT 1
    ) mv_adj ON TRUE
    WHERE fa.factura_id = f.id
) adj ON TRUE;

\echo 'Vista permisos.vw_facturas_publicadas_ofertadas_base actualizada.'

-- ============================================================================
-- PASO 8: Renombrar columnas
-- ============================================================================

\echo ''
\echo 'Paso 8: Renombrando columnas...'

-- Renombrar columna antigua para mantener backup
ALTER TABLE factura.factura 
RENAME COLUMN monto_total TO monto_total_legacy;

-- Renombrar nueva columna al nombre definitivo
ALTER TABLE factura.factura 
RENAME COLUMN monto_total_decimal TO monto_total;

\echo 'Columnas renombradas: monto_total_legacy, monto_total (DECIMAL).'

-- ============================================================================
-- PASO 9: Agregar constraint NOT NULL
-- ============================================================================

\echo ''
\echo 'Paso 9: Validando datos antes de NOT NULL...'

SELECT COUNT(*) AS facturas_con_monto_null
FROM factura.factura 
WHERE monto_total IS NULL;

-- Solo aplicar NOT NULL si no hay NULLs inesperados
DO $$
DECLARE
    null_count INT;
BEGIN
    SELECT COUNT(*) INTO null_count 
    FROM factura.factura 
    WHERE monto_total IS NULL;
    
    IF null_count = 0 THEN
        ALTER TABLE factura.factura ALTER COLUMN monto_total SET NOT NULL;
        RAISE NOTICE 'Constraint NOT NULL aplicado correctamente.';
    ELSE
        RAISE WARNING 'ADVERTENCIA: % facturas tienen monto_total NULL. Revisar antes de aplicar NOT NULL.', null_count;
    END IF;
END $$;

-- ============================================================================
-- PASO 10: Actualizar constraint UNIQUE
-- ============================================================================

\echo ''
\echo 'Paso 10: Recreando constraint UNIQUE...'

-- El constraint unique_factura_emisor_folio no referencia monto_total, 
-- pero verificar que sigue funcionando
SELECT constraint_name, constraint_type 
FROM information_schema.table_constraints 
WHERE table_schema = 'factura' AND table_name = 'factura';

COMMIT;

-- ============================================================================
-- PASO 11: Verificación final
-- ============================================================================

\echo ''
\echo '========================================='
\echo 'VERIFICACIÓN FINAL'
\echo '========================================='

\echo ''
\echo 'Estructura de columnas monto_total:'
SELECT 
    column_name, 
    data_type, 
    character_maximum_length, 
    numeric_precision, 
    numeric_scale,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'factura' 
  AND table_name = 'factura' 
  AND column_name LIKE 'monto_total%'
ORDER BY column_name;

\echo ''
\echo 'Estadísticas de datos migrados:'
SELECT 
    COUNT(*) AS total_facturas,
    MIN(monto_total) AS monto_minimo,
    MAX(monto_total) AS monto_maximo,
    AVG(monto_total) AS monto_promedio,
    SUM(monto_total) AS suma_total
FROM factura.factura;

\echo ''
\echo 'Vistas actualizadas:'
SELECT table_schema, table_name, view_definition 
FROM information_schema.views 
WHERE table_schema IN ('factura', 'permisos')
  AND view_definition LIKE '%monto_total%'
ORDER BY table_schema, table_name;

\echo ''
\echo '========================================='
\echo 'MIGRACIÓN COMPLETADA'
\echo '========================================='
\echo ''
\echo 'IMPORTANTE:'
\echo '1. Probar queries del marketplace con nuevo tipo DECIMAL'
\echo '2. Verificar calculadora de liquidación (HU-06)'
\echo '3. Validar vistas de reportería'
\echo '4. Monitorear logs de backend NestJS (ms-core, bff_seis_app)'
\echo ''
\echo 'Backup disponible en: factura.factura_backup_monto_total_20260726'
\echo ''

-- =============================================================================
-- ROLLBACK (en caso de error crítico)
-- =============================================================================
/*
BEGIN;

-- Restaurar columna original
ALTER TABLE factura.factura RENAME COLUMN monto_total TO monto_total_temp_decimal;
ALTER TABLE factura.factura RENAME COLUMN monto_total_legacy TO monto_total;

-- Eliminar columna temporal
ALTER TABLE factura.factura DROP COLUMN monto_total_temp_decimal;

-- Restaurar vistas (ejecutar 08_init_invoice.sql completo)

COMMIT;
*/
