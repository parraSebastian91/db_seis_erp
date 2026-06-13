

CREATE SCHEMA IF NOT EXISTS media;

-- Definición de tipos
CREATE TYPE media.media_status AS ENUM ('PENDING', 'UPLOADED', 'PROCESSING', 'READY', 'ERROR');
CREATE TYPE media.media_type AS ENUM ('IMAGE', 'VIDEO', 'DOCUMENT', 'ARCHIVE');

-- Tabla principal
CREATE TABLE media.media_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL,
    m_type media.media_type NOT NULL,
    category VARCHAR(50) NOT NULL, -- Ej: 'USER_AVATAR'
    status media."media_status" DEFAULT 'PENDING',
    original_name TEXT,
    mime_type VARCHAR(100),
    storage_key TEXT, -- Ruta en MinIO Temp
    error_log TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de variantes
CREATE TABLE media.media_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES media.media_assets(id) ON DELETE CASCADE,
    variant_name VARCHAR(50) NOT NULL, -- Ej: 'sm', 'md', 'lg'
    url_path TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_media_assets_storage_key ON media.media_assets(storage_key);

ALTER TYPE media.media_status ADD VALUE 'DEPRECATED';
ALTER TABLE media.media_variants ALTER COLUMN variant_name TYPE varchar(100) USING variant_name::varchar(100);
ALTER TABLE media.media_assets ADD correlation_id varchar NULL;
-- Índices para velocidad
CREATE INDEX idx_media_owner ON media.media_assets(owner_id);
CREATE INDEX idx_media_status ON media.media_assets(status);

-- =========================================================
-- CATÁLOGO DE CATEGORÍAS DE ASSETS
-- Fuente de verdad: CATEGORY_PROCESS_* en constantes_model.go
-- =========================================================
CREATE TABLE media.categoria (
    codigo      VARCHAR(50)  PRIMARY KEY,                   -- CATEGORY_PROCESS_* value (ej: 'DTE-factura')
    nombre      VARCHAR(100) NOT NULL,                      -- Nombre legible (ej: 'Factura DTE')
    media_type  media.media_type NOT NULL,                  -- Tipo de media válido para esta categoría
    activo      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO media.categoria (codigo, nombre, media_type) VALUES
    ('user-avatar',             'Avatar de usuario',         'IMAGE'),
    ('user-banner',             'Banner de usuario',         'IMAGE'),
    ('DTE-factura',             'Factura DTE (documento)',   'DOCUMENT'),
    ('DTE-factura-respaldo',    'Respaldo Factura DTE',      'DOCUMENT'),
    ('social-post',             'Publicación social',        'IMAGE'),
    ('orden-compra',            'Orden de compra',           'DOCUMENT'),
    ('hoja-entrada-servicio',   'Hoja entrada de servicio',  'DOCUMENT'),
    ('guia-despacho',           'Guía de despacho',          'DOCUMENT'),
    ('acta-entrega',            'Acta de entrega',           'DOCUMENT'),
    ('estado-pago',             'Estado de pago',            'DOCUMENT')
ON CONFLICT (codigo) DO NOTHING;

-- Prevenir cadenas vacías en category (causa del SQL Error [23503])
ALTER TABLE media.media_assets
    ADD CONSTRAINT chk_media_assets_category_not_empty
    CHECK (category <> '');

-- Sanear filas preexistentes con category vacío antes de crear la FK
UPDATE media.media_assets SET category = NULL WHERE category = '';

-- FK: media_assets.category → media.categoria.codigo
-- NOT VALID: no valida filas preexistentes al aplicar; usar VALIDATE CONSTRAINT en migraciones posteriores
ALTER TABLE media.media_assets
    ADD CONSTRAINT fk_media_assets_categoria
    FOREIGN KEY (category) REFERENCES media.categoria (codigo)
    ON UPDATE CASCADE
    NOT VALID;

CREATE INDEX idx_media_categoria ON media.media_assets (category);

-- =========================================================
-- CATÁLOGO DE MIME TYPES SOPORTADOS
-- Fuente de verdad: receta_model.go + worker-storage-processor
-- =========================================================
CREATE TABLE media.mime_type_soportado (
    mime_type       VARCHAR(100)     PRIMARY KEY,          -- Ej: 'application/pdf'
    extension       VARCHAR(20)      NOT NULL,             -- Ej: 'pdf'
    media_type      media.media_type NOT NULL,             -- Clasificación general
    descripcion     VARCHAR(100)     NOT NULL,
    ocr_soportado   BOOLEAN          NOT NULL DEFAULT FALSE, -- ¿El worker puede hacer OCR?
    activo          BOOLEAN          NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT now()
);

INSERT INTO media.mime_type_soportado (mime_type, extension, media_type, descripcion, ocr_soportado) VALUES
    -- Imágenes (procesadas por RECIPE_IMAGE → webp)
    ('image/jpeg',                                                          'jpg',   'IMAGE',    'JPEG Image',                    FALSE),
    ('image/png',                                                           'png',   'IMAGE',    'PNG Image',                     FALSE),
    ('image/webp',                                                          'webp',  'IMAGE',    'WebP Image',                    FALSE),
    ('image/gif',                                                           'gif',   'IMAGE',    'GIF Image',                     FALSE),
    -- Documentos (procesados por RECIPE_DOCUMENT → OCR)
    ('application/pdf',                                                     'pdf',   'DOCUMENT', 'PDF Document',                  TRUE),
    ('text/xml',                                                            'xml',   'DOCUMENT', 'XML (DTE SII)',                  TRUE),
    ('application/xml',                                                     'xml',   'DOCUMENT', 'Application XML',               TRUE),
    ('application/vnd.ms-excel',                                            'xls',   'DOCUMENT', 'Excel 97-2003',                 FALSE),
    ('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',   'xlsx',  'DOCUMENT', 'Excel OpenXML',                 FALSE),
    ('application/msword',                                                  'doc',   'DOCUMENT', 'Word 97-2003',                  FALSE),
    ('application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'docx', 'DOCUMENT', 'Word OpenXML',              FALSE),
    -- Archivos comprimidos
    ('application/zip',                                                     'zip',   'ARCHIVE',  'ZIP Archive',                   FALSE),
    ('application/x-tar',                                                   'tar',   'ARCHIVE',  'TAR Archive',                   FALSE)
ON CONFLICT (mime_type) DO NOTHING;

-- FK: media_assets.mime_type → media.mime_type_soportado.mime_type
-- NOT VALID: no valida filas preexistentes; ejecutar VALIDATE CONSTRAINT tras limpiar datos legacy
ALTER TABLE media.media_assets
    ADD CONSTRAINT fk_media_assets_mime_type
    FOREIGN KEY (mime_type) REFERENCES media.mime_type_soportado (mime_type)
    ON UPDATE CASCADE
    NOT VALID;

CREATE INDEX idx_media_assets_mime_type ON media.media_assets (mime_type);
