-- =============================================================
-- Tabla: factura.notas_ocr
-- Propósito: Registrar discrepancias detectadas al comparar los
--            datos declarados por el usuario en el formulario de
--            publicación vs. los valores extraídos por OCR al
--            procesar el documento de respaldo.
-- Dependencias: factura.factura
-- =============================================================

CREATE TABLE IF NOT EXISTS factura.notas_ocr (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    factura_id     UUID        NOT NULL REFERENCES factura.factura(id) ON DELETE CASCADE,
    campo          VARCHAR(100) NOT NULL,      -- nombre lógico del campo comparado
    valor_declarado TEXT,                      -- valor que ingresó el usuario en el formulario
    valor_ocr       TEXT,                      -- valor que capturó el OCR
    nota           TEXT        NOT NULL,       -- mensaje legible para mostrar al usuario
    resuelto       BOOLEAN     NOT NULL DEFAULT FALSE, -- el usuario marcó la discrepancia como revisada
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notas_ocr_factura_id
    ON factura.notas_ocr (factura_id);

COMMENT ON TABLE factura.notas_ocr IS
    'Discrepancias OCR vs. datos declarados por emisor. Visibles al usuario en la vista de factura (notifications-list).';
