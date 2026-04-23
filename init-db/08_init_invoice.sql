create schema if not exists factura;

CREATE TYPE factura_status AS ENUM (
    'PENDIENTE_VALIDACION',
    'PUBLICADA',
    'OFERTADA',
    'FINANCIADA',
    'PAGADA',
    'RECHAZADA',
    'CANCELADA',
    'VENCIDA',
    'DENUNCIADA'
);

CREATE TYPE offer_status AS ENUM ('ENVIADA', 'REVISADA', 'ACEPTADA', 'RECHAZADA');

CREATE TABLE
    factura.factura (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
        asset_id UUID REFERENCES media.media_assets (id), -- Tu tabla de storage
        organizacion_id UUID NOT NULL REFERENCES core.organizacion (organizacion_uuid), -- Empresa que sube la factura
        deudor_nombre VARCHAR(255) NOT NULL, -- Nombre del deudor (extraído por OCR)
        deudor_rut VARCHAR(20) NOT NULL, -- RUT del que debe pagar la factura (extraído por OCR)
        factura_numero VARCHAR(50) NOT NULL, -- Folio (extraído por OCR)
        monto_total DECIMAL(15, 2) NOT NULL CHECK (monto_total > 0), -- Monto (extraído por OCR)
        fecha_vencimiento DATE NOT NULL, -- Vencimiento (extraído por OCR)
        status factura_status NOT NULL DEFAULT 'PENDIENTE_VALIDACION', -- PENDIENTE_VALIDACION, PUBLICADA, OFERTADA, FINANCIADA, PAGADA, RECHAZADA, CANCELADA, VENCIDA, DENUNCIADA
        created_at TIMESTAMP
        WITH
            TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP
        WITH
            TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
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