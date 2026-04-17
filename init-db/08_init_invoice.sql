create schema if not exists factura;

CREATE TABLE
    factura.factura (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
        asset_id UUID REFERENCES media.media_assets (id), -- Tu tabla de storage
        organizacion_id UUID REFERENCES core.organizacion (organizacion_uuid), -- Empresa que sube la factura
        deudor_nombre VARCHAR(255), -- Nombre del deudor (extraído por OCR)
        deudor_rut VARCHAR(20), -- RUT del que debe pagar la factura (extraído por OCR)
        factura_numero VARCHAR(50), -- Folio (extraído por OCR)
        monto_total DECIMAL(15, 2), -- Monto (extraído por OCR)
        fecha_vencimiento DATE, -- Vencimiento (extraído por OCR)
        status factura_status DEFAULT 'PENDING_VALIDATION', -- PENDING, OPEN, NEGOTIATING, FUNDED
        created_at TIMESTAMP
        WITH
            TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

CREATE TABLE
    factura.ofertas (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
        factura_id UUID REFERENCES factura.factura (id),
        investor_id UUID REFERENCES core.usuario (usuario_uuid), -- Ejecutiva/Empresa de Factoring
        tasa DECIMAL(5, 4), -- Tasa propuesta (ej: 0.0150 para 1.5%)
        monto_oferta DECIMAL(15, 2), -- Cuánto dinero le llegará a la empresa
        status offer_status DEFAULT 'SENT' -- SENT, ACCEPTED, REJECTED
    );

CREATE TABLE
    factura.historial_negocios (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
        factura_id UUID NOT NULL REFERENCES factura.factura (id),
        organizacion_id UUID NOT NULL REFERENCES core.organizacion (organizacion_uuid), -- El emisor
        usuario_id UUID NOT NULL REFERENCES core.usuario (usuario_uuid), -- La ejecutiva (Investor)
        -- Calificaciones cruzadas (Estilo Uber/Airbnb)
        calificacion_a_organizacion decimal(3, 2), -- Ejecutiva califica a empresa
        calificacion_a_usuario decimal(3, 2), -- Empresa califica a ejecutiva
        comentarios_empresa text,
        comentarios_ejecutiva text,
        monto_final_operado decimal(15, 2),
        created_at TIMESTAMP
        WITH
            TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

CREATE TABLE
    factura.relaciones_preferidas (
        organizacion_id UUID REFERENCES core.organizacion (organizacion_uuid),
        usuario_id UUID REFERENCES core.usuario (usuario_uuid),
        total_operaciones INT DEFAULT 1,
        monto_total_acumulado DECIMAL(15, 2),
        promedio_calificacion DECIMAL(3, 2),
        PRIMARY KEY (organizacion_id, usuario_id)
    );

-- Índice para buscar rápido "con quién ha trabajado esta empresa"
CREATE INDEX idx_historial_relacion ON factura.historial_negocios (organizacion_id, usuario_id);

ALTER TABLE factura.historial_negocios 
ADD CONSTRAINT unique_invoice_deal UNIQUE (factura_id);

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
-- WHERE f.status = 'OPEN';