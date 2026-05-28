create schema if not exists factura;

CREATE TYPE factura.factura_status AS ENUM (
    'PENDIENTE_VALIDACION',
    'PENDIENTE_AUTORIZACION',
    'PUBLICADA',
    'OFERTADA',
    'FINANCIADA',
    'PAGADA',
    'RECHAZADA',
    'CANCELADA',
    'VENCIDA',
    'DENUNCIADA'
);

CREATE TYPE factura.offer_status AS ENUM ('ENVIADA', 'REVISADA', 'ACEPTADA', 'RECHAZADA');
CREATE TYPE factura.create_by AS ENUM ('FORM', 'OCR', 'AGENT');

CREATE TABLE
    factura.factura (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
        asset_id UUID REFERENCES media.media_assets (id), -- Tu tabla de storage
        organizacion_id UUID NOT NULL REFERENCES core.organizacion (organizacion_uuid), -- Empresa que sube la factura
        deudor_nombre VARCHAR(255) NOT NULL, -- Nombre del deudor (extraído por OCR)
        deudor_rut VARCHAR(255) NOT NULL, -- RUT del que debe pagar la factura (extraído por OCR)
        factura_numero VARCHAR(255) NOT NULL, -- Folio (extraído por OCR)
        monto_total VARCHAR(255) NOT null, -- Monto (extraído por OCR)
        fecha_vencimiento DATE NOT NULL, -- Vencimiento (extraído por OCR)
        status factura_status NOT NULL DEFAULT 'PENDIENTE_VALIDACION', -- PENDIENTE_VALIDACION, PUBLICADA, OFERTADA, FINANCIADA, PAGADA, RECHAZADA, CANCELADA, VENCIDA, DENUNCIADA
        created_at TIMESTAMP
        WITH
            TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP
        WITH
            TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        created_by factura.create_by NOT NULL DEFAULT 'FORM',
        CONSTRAINT unique_factura_emisor_folio UNIQUE (organizacion_id, deudor_rut, factura_numero)
    );

CREATE TABLE
    factura.ofertas (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
        factura_id UUID NOT NULL REFERENCES factura.factura (id),
        financiadora_id UUID NOT NULL REFERENCES core.organizacion (organizacion_uuid), -- Empresa de factoring/financiadora
        investor_id UUID NOT NULL REFERENCES core.usuario (usuario_uuid), -- Ejecutiva de la financiadora
        tasa DECIMAL(5, 4) NOT NULL CHECK (tasa > 0 AND tasa <= 1), -- Tasa propuesta (ej: 0.0150 para 1.5%)
        monto_oferta DECIMAL(15, 2) NOT NULL CHECK (monto_oferta > 0), -- Cuánto dinero le llegará a la empresa
        status offer_status NOT NULL DEFAULT 'ENVIADA', -- ENVIADA, REVISADA, ACEPTADA, RECHAZADA
        created_at TIMESTAMP
        WITH
            TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP
        WITH
            TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

CREATE TABLE
    factura.historial_negocios (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
        factura_id UUID NOT NULL REFERENCES factura.factura (id),
        organizacion_id UUID NOT NULL REFERENCES core.organizacion (organizacion_uuid), -- El emisor
        financiadora_id UUID NOT NULL REFERENCES core.organizacion (organizacion_uuid), -- La empresa financiadora
        usuario_id UUID NOT NULL REFERENCES core.usuario (usuario_uuid), -- La ejecutiva (Investor)
        -- Calificaciones cruzadas (Estilo Uber/Airbnb)
        calificacion_a_organizacion decimal(3, 2) CHECK (calificacion_a_organizacion BETWEEN 1 AND 5), -- Ejecutiva califica a empresa
        calificacion_a_usuario decimal(3, 2) CHECK (calificacion_a_usuario BETWEEN 1 AND 5), -- Empresa califica a ejecutiva
        comentarios_empresa text,
        comentarios_ejecutiva text,
        monto_final_operado decimal(15, 2) NOT NULL CHECK (monto_final_operado > 0),
        created_at TIMESTAMP
        WITH
            TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

CREATE TABLE
    factura.relaciones_preferidas (
        organizacion_id UUID NOT NULL REFERENCES core.organizacion (organizacion_uuid), -- Cliente emisor
        financiadora_id UUID NOT NULL REFERENCES core.organizacion (organizacion_uuid), -- Empresa financiadora
        usuario_id UUID NOT NULL REFERENCES core.usuario (usuario_uuid), -- Ejecutiva principal de la relación
        total_operaciones INT NOT NULL DEFAULT 0 CHECK (total_operaciones >= 0),
        monto_total_acumulado DECIMAL(15, 2) NOT NULL DEFAULT 0 CHECK (monto_total_acumulado >= 0),
        promedio_calificacion_a_organizacion DECIMAL(3, 2) CHECK (promedio_calificacion_a_organizacion BETWEEN 1 AND 5),
        promedio_calificacion_a_usuario DECIMAL(3, 2) CHECK (promedio_calificacion_a_usuario BETWEEN 1 AND 5),
        ultima_operacion_at TIMESTAMP WITH TIME ZONE,
        score_fidelidad DECIMAL(6, 4) NOT NULL DEFAULT 0 CHECK (score_fidelidad >= 0 AND score_fidelidad <= 1),
        created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (organizacion_id, financiadora_id, usuario_id)
    );

-- Tabla de control de cambios para entidades del dominio factura
CREATE TABLE IF NOT EXISTS factura.control_cambios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    entidad VARCHAR(100) NOT NULL, -- Ej: factura, ofertas, historial_negocios
    entidad_id UUID NOT NULL,
    accion VARCHAR(30) NOT NULL, -- INSERT, UPDATE, DELETE, STATUS_CHANGE
    campo VARCHAR(100), -- Campo afectado cuando aplica
    valor_anterior TEXT,
    valor_nuevo TEXT,
    usuario_uuid UUID REFERENCES core.usuario (usuario_uuid),
    correlation_id UUID,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_control_cambios_entidad_entidad_id
    ON factura.control_cambios (entidad, entidad_id, created_at DESC);
CREATE INDEX idx_control_cambios_usuario
    ON factura.control_cambios (usuario_uuid, created_at DESC);
CREATE INDEX idx_control_cambios_correlation
    ON factura.control_cambios (correlation_id);



--   El consentimiento necesita: inmutabilidad garantizada, versión de términos,
--   y transición atómica de estado.
-- =============================================================================

-- ─────────────────────────────────────────────────────────
-- 1. CATÁLOGO DE VERSIONES DE TÉRMINOS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS factura.version_terminos (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo          VARCHAR(20)  NOT NULL UNIQUE,   -- 'v1.0', 'v2.1'
    descripcion     VARCHAR(255) NOT NULL,
    texto_completo  TEXT         NOT NULL,
    hash_sha256     CHAR(64)     NOT NULL,           -- prueba de qué texto vio el usuario
    activo          BOOLEAN      NOT NULL DEFAULT TRUE,
    vigente_desde   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    vigente_hasta   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Solo una versión activa a la vez
CREATE UNIQUE INDEX uq_version_terminos_activa
    ON factura.version_terminos (activo)
    WHERE activo = TRUE;


-- ─────────────────────────────────────────────────────────
-- 2. REGISTRO DE CONSENTIMIENTO (APPEND-ONLY)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS factura.autorizacion_publicacion (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    factura_id          UUID        NOT NULL REFERENCES factura.factura(id),
    usuario_uuid        UUID        NOT NULL REFERENCES core.usuario(usuario_uuid),
    organizacion_id     UUID        NOT NULL REFERENCES core.organizacion(organizacion_uuid),
    version_terminos_id UUID        NOT NULL REFERENCES factura.version_terminos(id),
    acepto              BOOLEAN     NOT NULL,        -- TRUE = aceptó, FALSE = rechazó
    ip_address          INET,
    user_agent          TEXT,
    correlation_id      UUID,                        -- mismo correlation_id de la factura
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Solo UN acepto=TRUE por factura
CREATE UNIQUE INDEX uq_autorizacion_aceptada_por_factura
    ON factura.autorizacion_publicacion (factura_id)
    WHERE acepto = TRUE;

CREATE INDEX idx_autorizacion_factura    ON factura.autorizacion_publicacion (factura_id, created_at DESC);
CREATE INDEX idx_autorizacion_usuario    ON factura.autorizacion_publicacion (usuario_uuid, created_at DESC);
CREATE INDEX idx_autorizacion_correlation ON factura.autorizacion_publicacion (correlation_id);



-- =========================================================
-- CONTROL DE CAMBIOS AUTOMATICO (TRIGGERS)
-- =========================================================

CREATE OR REPLACE FUNCTION factura.tr_registrar_control_cambios()
RETURNS TRIGGER AS $$
DECLARE
    v_entidad TEXT := TG_TABLE_NAME;
    v_entidad_id UUID;
    v_accion VARCHAR(30);
    v_campo VARCHAR(100) := NULL;
    v_valor_anterior TEXT := NULL;
    v_valor_nuevo TEXT := NULL;
    v_usuario_text TEXT := current_setting('app.user_uuid', true);
    v_correlation_text TEXT := current_setting('app.correlation_id', true);
    v_usuario_uuid UUID := NULL;
    v_correlation_id UUID := NULL;
    v_metadata JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_entidad_id := NEW.id;
        v_accion := 'INSERT';
        v_metadata := jsonb_build_object('new', to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        v_entidad_id := NEW.id;
        v_accion := 'UPDATE';
        v_metadata := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));

        IF to_jsonb(OLD) ? 'status' AND to_jsonb(NEW) ? 'status' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
            v_accion := 'STATUS_CHANGE';
            v_campo := 'status';
            v_valor_anterior := OLD.status::TEXT;
            v_valor_nuevo := NEW.status::TEXT;
        END IF;
    ELSE
        v_entidad_id := OLD.id;
        v_accion := 'DELETE';
        v_metadata := jsonb_build_object('old', to_jsonb(OLD));
    END IF;

    IF v_usuario_text IS NOT NULL THEN
        BEGIN
            v_usuario_uuid := v_usuario_text::UUID;
        EXCEPTION WHEN others THEN
            v_usuario_uuid := NULL;
        END;
    END IF;

    IF v_correlation_text IS NOT NULL THEN
        BEGIN
            v_correlation_id := v_correlation_text::UUID;
        EXCEPTION WHEN others THEN
            v_correlation_id := NULL;
        END;
    END IF;

    INSERT INTO factura.control_cambios (
        entidad,
        entidad_id,
        accion,
        campo,
        valor_anterior,
        valor_nuevo,
        usuario_uuid,
        correlation_id,
        metadata
    ) VALUES (
        v_entidad,
        v_entidad_id,
        v_accion,
        v_campo,
        v_valor_anterior,
        v_valor_nuevo,
        v_usuario_uuid,
        v_correlation_id,
        v_metadata
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- Vista: facturas_publicadas_con_datos
-- Facturas publicadas enriquecidas con datos del cliente y gestor.
-- =========================================================
CREATE OR REPLACE VIEW factura.vw_facturas_publicadas_con_datos AS
SELECT
    fct.id AS factura_id,
    fct.factura_numero AS folio,
    fct.deudor_nombre,
    fct.deudor_rut,
    fct.monto_total,
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
    JOIN core.usuario u ON fct.gestor_usuario_uuid = u.usuario_uuid
    JOIN core.contacto c ON u.contacto_id = c.contacto_id
WHERE
    fct.status = 'PUBLICADA';

-- =========================================================
-- Función: validar_usuario_ejecutivo_financiadora
-- Verifica si un usuario es EJECUTIVO_FINANCIADORA o ADMIN_FINANCIADORA.
-- Retorna TRUE si es válido.
-- =========================================================
CREATE OR REPLACE FUNCTION factura.validar_usuario_ejecutivo_financiadora(
    p_usuario_uuid UUID
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM core.usuario u
        JOIN core.grupo_miembro gm ON gm.usuario_uuid = u.usuario_uuid
        JOIN core.grupo_trabajo gt ON gt.grupo_id = gm.grupo_id
        JOIN core.organizacion o ON o.organizacion_uuid = gt.organizacion_id
        JOIN core.usuario_rol ur ON u.usuario_id = ur.usuario_id
        JOIN core.rol r ON r.rol_id = ur.rol_id
        WHERE
            u.usuario_uuid = p_usuario_uuid
            AND u.activo = TRUE
            AND o.activo = TRUE
            AND o.tipo_participante = 'FINANCIADORA'
            AND r.codigo IN ('EJECUTIVO_FINANCIADORA', 'ADMIN_FINANCIADORA')
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- =========================================================
-- Función: obtener_facturas_accesibles
-- Retorna todas las facturas PUBLICADAS que un usuario puede ver.
-- Filtra por permisos y rol de financiadora.
--
-- Parámetros:
--   p_usuario_uuid:  usuario que solicita ver facturas
--   p_organizacion_id: organización del usuario (financiadora)
--
-- Retorna tabla con: factura_id, folio, cliente, monto, fecha_vencimiento, ...
-- =========================================================
CREATE OR REPLACE FUNCTION factura.obtener_facturas_accesibles(
    p_usuario_uuid UUID,
    p_organizacion_id UUID
) RETURNS TABLE (
    factura_id UUID,
    folio VARCHAR,
    deudor_nombre VARCHAR,
    deudor_rut VARCHAR,
    monto_total VARCHAR,
    cliente_nombre VARCHAR,
    cliente_rut VARCHAR,
    gestor_id UUID,
    gestor_nombre VARCHAR,
    fecha_vencimiento DATE,
    status VARCHAR,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    tiene_permiso BOOLEAN
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
        fct.monto_total,
        o.razon_social,
        o.rut,
        u.usuario_uuid,
        CONCAT(c.nombres, ' ', c.apellido_paterno, ' ', c.apellido_materno),
        fct.fecha_vencimiento,
        fct.status::VARCHAR,
        fct.created_at,
        fct.updated_at,
        permisos.check_access('FACTURA', fct.id, p_usuario_uuid, 'VIEW', p_organizacion_id) AS tiene_permiso
    FROM
        factura.factura fct
        JOIN core.organizacion o ON o.organizacion_uuid = fct.organizacion_id
        JOIN core.usuario u ON fct.gestor_usuario_uuid = u.usuario_uuid
        JOIN core.contacto c ON u.contacto_id = c.contacto_id
    WHERE
        fct.status = 'PUBLICADA'
        AND (
            -- Usuario tiene acceso directo, por grupo o cross-org
            permisos.check_access('FACTURA', fct.id, p_usuario_uuid, 'VIEW', p_organizacion_id)
            OR
            -- O es propietario
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

-- =========================================================
-- Vista: facturas_accesibles_para_financiadora
-- Facturas que una financiadora (por org_id) puede ver.
-- Parámetro externo: requiere filtro en WHERE.
--
-- Uso: 
--   SELECT * FROM factura.vw_facturas_accesibles_por_org
--   WHERE organizacion_id = :financiera_org_uuid;
-- =========================================================
CREATE OR REPLACE VIEW factura.vw_facturas_accesibles_por_org AS
SELECT
    fct.id AS factura_id,
    fct.factura_numero AS folio,
    fct.deudor_nombre,
    fct.deudor_rut,
    fct.monto_total,
    o.razon_social AS cliente_nombre,
    o.rut AS cliente_rut,
    u.usuario_uuid AS gestor_id,
    CONCAT(c.nombres, ' ', c.apellido_paterno, ' ', c.apellido_materno) AS gestor_nombre,
    fct.fecha_vencimiento,
    fct.status,
    fct.created_at,
    fct.updated_at,
    gt.organizacion_id AS financiera_org_id
FROM
    factura.factura fct
    JOIN core.organizacion o ON o.organizacion_uuid = fct.organizacion_id
    JOIN core.usuario u ON fct.gestor_usuario_uuid = u.usuario_uuid
    JOIN core.contacto c ON u.contacto_id = c.contacto_id
    -- Traer los permisos concedidos
    JOIN permisos.access_policy ap ON ap.resource_type = 'FACTURA'
        AND ap.resource_id = fct.id
        AND ap.revoked_at IS NULL
        AND (ap.expires_at IS NULL OR ap.expires_at > NOW())
    JOIN core.grupo_trabajo gt ON gt.grupo_id = ap.grantee_grupo_id
        AND gt.activo = TRUE
WHERE
    fct.status = 'PUBLICADA'
    AND (ap.grantee_grupo_id IS NOT NULL OR ap.grantee_usuario_uuid IS NOT NULL);


DROP TRIGGER IF EXISTS tr_control_cambios_factura ON factura.factura;
CREATE TRIGGER tr_control_cambios_factura
AFTER INSERT OR UPDATE OR DELETE ON factura.factura
FOR EACH ROW EXECUTE FUNCTION factura.tr_registrar_control_cambios();

DROP TRIGGER IF EXISTS tr_control_cambios_ofertas ON factura.ofertas;
CREATE TRIGGER tr_control_cambios_ofertas
AFTER INSERT OR UPDATE OR DELETE ON factura.ofertas
FOR EACH ROW EXECUTE FUNCTION factura.tr_registrar_control_cambios();

-- ─────────────────────────────────────────────────────────
-- 3. TRIGGER: INMUTABILIDAD
-- Ningún UPDATE ni DELETE es posible, ni por ADMIN.
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION factura.tr_autorizacion_immutable()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION
        'autorizacion_publicacion es append-only — % no está permitido. '
        'Un consentimiento registrado no puede modificarse.', TG_OP;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_autorizacion_no_mutate
BEFORE UPDATE OR DELETE ON factura.autorizacion_publicacion
FOR EACH ROW EXECUTE FUNCTION factura.tr_autorizacion_immutable();




-- ─────────────────────────────────────────────────────────
-- 5. HELPER: verificar consentimiento vigente
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION factura.tiene_autorizacion_vigente(p_factura_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM factura.autorizacion_publicacion
        WHERE factura_id = p_factura_id AND acepto = TRUE
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Índice para buscar rápido "con quién ha trabajado esta empresa"
CREATE INDEX idx_historial_relacion ON factura.historial_negocios (organizacion_id, usuario_id);
CREATE INDEX idx_historial_financiadora_relacion ON factura.historial_negocios (organizacion_id, financiadora_id, usuario_id);

CREATE INDEX idx_factura_estado ON factura.factura (status);
CREATE INDEX idx_factura_org_estado ON factura.factura (organizacion_id, status);
CREATE INDEX idx_factura_vencimiento ON factura.factura (fecha_vencimiento);

CREATE INDEX idx_ofertas_factura_status ON factura.ofertas (factura_id, status);
CREATE INDEX idx_ofertas_financiadora ON factura.ofertas (financiadora_id);
CREATE INDEX idx_ofertas_investor ON factura.ofertas (investor_id);

-- Solo una oferta ACEPTADA por factura
CREATE UNIQUE INDEX uq_oferta_aceptada_por_factura
ON factura.ofertas (factura_id)
WHERE status = 'ACEPTADA';

CREATE INDEX idx_relacion_preferida_org_financiadora ON factura.relaciones_preferidas (organizacion_id, financiadora_id);

ALTER TABLE factura.historial_negocios ADD CONSTRAINT unique_invoice_deal UNIQUE (factura_id);
ALTER TABLE factura.ofertas ADD revised_at timestamp NULL;
ALTER TABLE factura.factura ADD correlation_id uuid NOT NULL;
ALTER TABLE media.media_assets ADD gestor varchar NULL;
ALTER TABLE factura.factura
  ADD COLUMN gestor_usuario_uuid UUID;

ALTER TABLE factura.factura
  ADD CONSTRAINT fk_factura_gestor_usuario
  FOREIGN KEY (gestor_usuario_uuid)
  REFERENCES core.usuario(usuario_uuid)
  ON UPDATE CASCADE
  ON DELETE SET NULL;

CREATE INDEX idx_factura_gestor_usuario_uuid
  ON factura.factura (gestor_usuario_uuid);


-- querys utiles para la app
-- El detalle de la "Asistencia" en el Query:
-- Cuando la ejecutiva busque facturas, el backend le devolverá un campo calculado:
-- SELECT 
--     f.*,
--     (SELECT COUNT(*) FROM factura.historial_negocios h 
--      WHERE h.organizacion_id = f.organizacion_id AND h.usuario_id = $1) as matches_previos,
--     (SELECT AVG(calificacion_a_organizacion) FROM factura.historial_negocios h 
--      WHERE h.organizacion_id = f.organizacion_id) as reputacion_emisor
-- FROM factura.factura f
-- WHERE f.status = 'PUBLICADA';

-- =========================================================
-- VISTAS OPERATIVAS Y ANALITICAS
-- =========================================================

-- Resumen de ofertas por factura (conteos y mejor oferta)
CREATE OR REPLACE VIEW factura.vw_factura_ofertas_resumen AS
SELECT
    f.id AS factura_id,
    f.organizacion_id,
    f.deudor_rut,
    f.factura_numero,
    f.monto_total,
    f.fecha_vencimiento,
    f.status AS factura_status,
    COUNT(o.id) AS total_ofertas,
    COUNT(*) FILTER (WHERE o.status = 'ENVIADA') AS ofertas_enviadas,
    COUNT(*) FILTER (WHERE o.status = 'REVISADA') AS ofertas_revisadas,
    COUNT(*) FILTER (WHERE o.status = 'ACEPTADA') AS ofertas_aceptadas,
    COUNT(*) FILTER (WHERE o.status = 'RECHAZADA') AS ofertas_rechazadas,
    MIN(o.tasa) FILTER (WHERE o.id IS NOT NULL) AS mejor_tasa,
    MAX(o.monto_oferta) FILTER (WHERE o.id IS NOT NULL) AS mejor_monto_oferta,
    MAX(o.updated_at) FILTER (WHERE o.id IS NOT NULL) AS ultima_actualizacion_oferta
FROM factura.factura f
LEFT JOIN factura.ofertas o ON o.factura_id = f.id
GROUP BY
    f.id,
    f.organizacion_id,
    f.deudor_rut,
    f.factura_numero,
    f.monto_total,
    f.fecha_vencimiento,
    f.status;

-- Historial de relaciones cliente-financiadora-ejecutiva
CREATE OR REPLACE VIEW factura.vw_relacion_historial_resumen AS
SELECT
    h.organizacion_id,
    h.financiadora_id,
    h.usuario_id,
    COUNT(*) AS total_operaciones,
    SUM(h.monto_final_operado) AS monto_total_acumulado,
    AVG(h.calificacion_a_organizacion) AS promedio_calificacion_a_organizacion,
    AVG(h.calificacion_a_usuario) AS promedio_calificacion_a_usuario,
    MAX(h.created_at) AS ultima_operacion_at,
    MIN(h.created_at) AS primera_operacion_at
FROM factura.historial_negocios h
GROUP BY h.organizacion_id, h.financiadora_id, h.usuario_id;

-- Ranking de financiadoras por cliente con score de fidelidad simple
CREATE OR REPLACE VIEW factura.vw_ranking_financiadora_por_cliente AS
SELECT
    r.organizacion_id,
    r.financiadora_id,
    r.usuario_id,
    r.total_operaciones,
    r.monto_total_acumulado,
    r.promedio_calificacion_a_organizacion,
    r.promedio_calificacion_a_usuario,
    r.ultima_operacion_at,
    r.score_fidelidad,
    ROW_NUMBER() OVER (
        PARTITION BY r.organizacion_id
        ORDER BY r.score_fidelidad DESC, r.total_operaciones DESC, r.monto_total_acumulado DESC
    ) AS ranking_cliente
FROM factura.relaciones_preferidas r;

-- Facturas publicadas con señal de afinidad para una ejecutiva
CREATE OR REPLACE VIEW factura.vw_facturas_publicadas_para_matching AS
SELECT
    f.id AS factura_id,
    f.organizacion_id,
    f.deudor_rut,
    f.factura_numero,
    f.monto_total,
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

-- ─────────────────────────────────────────────────────────
-- 6. VERSIÓN INICIAL DE TÉRMINOS
-- Antes de producción, actualiza hash_sha256 con:
--   SELECT encode(sha256('<texto_completo>'::bytea), 'hex');
-- ─────────────────────────────────────────────────────────
INSERT INTO factura.version_terminos (codigo, descripcion, texto_completo, hash_sha256)
VALUES (
    'v1.0',
    'Términos iniciales de publicación en marketplace SEIS',
    'Al aceptar, autorizas la publicación de la factura en el marketplace SEIS y la notificación a entidades financieras para su evaluación. Declaras que la información es verídica y que tienes plena autoridad para ceder los derechos de cobro. Esta autorización queda registrada de forma permanente junto a los datos de tu sesión.',
    (SELECT encode(sha256('Al aceptar, autorizas la publicación de la factura en el marketplace SEIS y la notificación a entidades financieras para su evaluación. Declaras que la información es verídica y que tienes plena autoridad para ceder los derechos de cobro. Esta autorización queda registrada de forma permanente junto a los datos de tu sesión.'::bytea), 'hex'))
) ON CONFLICT (codigo) DO NOTHING;

-- =========================================================
-- CONSULTAS UTILES (PARAMETRIZABLES)
-- =========================================================

-- 1) Top financiadoras por cliente (organizacion)
-- Reemplazar :organizacion_id por UUID real
-- SELECT *
-- FROM factura.vw_ranking_financiadora_por_cliente
-- WHERE organizacion_id = :organizacion_id
-- ORDER BY ranking_cliente
-- LIMIT 10;

-- 2) Facturas publicadas priorizadas para una ejecutiva
-- Reemplazar :usuario_id por UUID real
-- SELECT *
-- FROM factura.vw_facturas_publicadas_para_matching
-- WHERE ejecutivo_relacionado = :usuario_id OR ejecutivo_relacionado IS NULL
-- ORDER BY score_fidelidad_relacion DESC, created_at DESC
-- LIMIT 100;

-- 3) Mejor oferta por factura publicada
-- SELECT
--     f.id AS factura_id,
--     f.factura_numero,
--     best.id AS oferta_id,
--     best.financiadora_id,
--     best.investor_id,
--     best.tasa,
--     best.monto_oferta,
--     best.status
-- FROM factura.factura f
-- LEFT JOIN LATERAL (
--     SELECT o.*
--     FROM factura.ofertas o
--     WHERE o.factura_id = f.id
--     ORDER BY o.tasa ASC, o.monto_oferta DESC, o.created_at ASC
--     LIMIT 1
-- ) best ON TRUE
-- WHERE f.status IN ('PUBLICADA', 'OFERTADA');

-- 4) Dashboard de performance de una financiadora
-- Reemplazar :financiadora_id por UUID real
-- SELECT
--     o.financiadora_id,
--     COUNT(*) AS total_ofertas,
--     COUNT(*) FILTER (WHERE o.status = 'ACEPTADA') AS total_aceptadas,
--     ROUND(
--         (COUNT(*) FILTER (WHERE o.status = 'ACEPTADA'))::numeric / NULLIF(COUNT(*), 0),
--         4
--     ) AS tasa_aceptacion,
--     AVG(o.tasa) AS tasa_promedio,
--     SUM(o.monto_oferta) AS monto_ofertado
-- FROM factura.ofertas o
-- WHERE o.financiadora_id = :financiadora_id
-- GROUP BY o.financiadora_id;

-- 5) Refrescar relaciones_preferidas desde historial_negocios
-- Recomendado ejecutar en job programado.
-- INSERT INTO factura.relaciones_preferidas (
--     organizacion_id,
--     financiadora_id,
--     usuario_id,
--     total_operaciones,
--     monto_total_acumulado,
--     promedio_calificacion_a_organizacion,
--     promedio_calificacion_a_usuario,
--     ultima_operacion_at,
--     score_fidelidad,
--     updated_at
-- )
-- SELECT
--     h.organizacion_id,
--     h.financiadora_id,
--     h.usuario_id,
--     COUNT(*) AS total_operaciones,
--     SUM(h.monto_final_operado) AS monto_total_acumulado,
--     AVG(h.calificacion_a_organizacion) AS promedio_calificacion_a_organizacion,
--     AVG(h.calificacion_a_usuario) AS promedio_calificacion_a_usuario,
--     MAX(h.created_at) AS ultima_operacion_at,
--     LEAST(
--         1,
--         (
--             0.40 * LEAST(COUNT(*)::numeric / 20, 1)
--             + 0.30 * LEAST(COALESCE(SUM(h.monto_final_operado), 0) / 100000000, 1)
--             + 0.20 * LEAST(COALESCE(AVG(h.calificacion_a_usuario), 0) / 5, 1)
--             + 0.10 * LEAST(
--                 GREATEST(0, 365 - (CURRENT_DATE - MAX(h.created_at)::date))::numeric / 365,
--                 1
--             )
--         )
--     ) AS score_fidelidad,
--     CURRENT_TIMESTAMP AS updated_at
-- FROM factura.historial_negocios h
-- GROUP BY h.organizacion_id, h.financiadora_id, h.usuario_id
-- ON CONFLICT (organizacion_id, financiadora_id, usuario_id)
-- DO UPDATE SET
--     total_operaciones = EXCLUDED.total_operaciones,
--     monto_total_acumulado = EXCLUDED.monto_total_acumulado,
--     promedio_calificacion_a_organizacion = EXCLUDED.promedio_calificacion_a_organizacion,
--     promedio_calificacion_a_usuario = EXCLUDED.promedio_calificacion_a_usuario,
--     ultima_operacion_at = EXCLUDED.ultima_operacion_at,
--     score_fidelidad = EXCLUDED.score_fidelidad,
--     updated_at = CURRENT_TIMESTAMP;