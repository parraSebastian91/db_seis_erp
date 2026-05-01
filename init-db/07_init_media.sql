

CREATE SCHEMA IF NOT EXISTS media;

-- Definición de tipos
CREATE TYPE media_status AS ENUM ('PENDING', 'UPLOADED', 'PROCESSING', 'READY', 'ERROR');
CREATE TYPE media_type AS ENUM ('IMAGE', 'VIDEO', 'DOCUMENT', 'ARCHIVE');

-- Tabla principal
CREATE TABLE media_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL,
    m_type media_type NOT NULL,
    category VARCHAR(50) NOT NULL, -- Ej: 'USER_AVATAR'
    status media_status DEFAULT 'PENDING',
    original_name TEXT,
    mime_type VARCHAR(100),
    storage_key TEXT, -- Ruta en MinIO Temp
    error_log TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de variantes
CREATE TABLE media_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES media_assets(id) ON DELETE CASCADE,
    variant_name VARCHAR(50) NOT NULL, -- Ej: 'sm', 'md', 'lg'
    url_path TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Índices para velocidad
CREATE INDEX idx_media_owner ON media_assets(owner_id);
CREATE INDEX idx_media_status ON media_assets(status);
CREATE UNIQUE INDEX idx_media_assets_storage_key ON media_assets(storage_key);

 ALTER TYPE media."media_status" ADD VALUE 'DEPRECATED';
 ALTER TABLE media.media_variants ALTER COLUMN variant_name TYPE varchar(100) USING variant_name::varchar(100);
