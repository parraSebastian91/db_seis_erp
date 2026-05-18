-- =============================================================================
-- Media Permissions Integration
-- Cadena de permisos para acceso a media_assets y presigned URLs
-- Relaciona core.usuarios con media.media_assets
-- =============================================================================

-- 2. TABLA: Relación de propietarios de media_assets con usuarios de CORE
-- (Enlaza media.media_assets con core.usuario)
CREATE TABLE IF NOT EXISTS core.media_asset_owner (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL REFERENCES media.media_assets(id) ON DELETE CASCADE,
    owner_usuario_uuid UUID NOT NULL REFERENCES core.usuario(usuario_uuid) ON DELETE CASCADE,
    organizacion_id UUID NOT NULL REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,
    es_propietario_principal BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(media_id, owner_usuario_uuid)
);

CREATE INDEX idx_media_asset_owner_usuario 
    ON core.media_asset_owner(owner_usuario_uuid);
CREATE INDEX idx_media_asset_owner_organizacion 
    ON core.media_asset_owner(organizacion_id);
CREATE INDEX idx_media_asset_owner_media 
    ON core.media_asset_owner(media_id);

-- 3. TABLA: Política de acceso a media_assets
-- Permite que usuarios/grupos dentro de la organización vean media assets específicos
CREATE TABLE IF NOT EXISTS core.media_access_policy (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL REFERENCES media.media_assets(id) ON DELETE CASCADE,
    
    -- Grantee: quién recibe permisos
    grantee_usuario_uuid UUID REFERENCES core.usuario(usuario_uuid) ON DELETE CASCADE,
    grantee_grupo_id UUID REFERENCES core.grupo_trabajo(grupo_id) ON DELETE CASCADE,
    
    -- Granter: quién otorga los permisos (debe ser owner o admin)
    granter_usuario_uuid UUID NOT NULL REFERENCES core.usuario(usuario_uuid) ON DELETE SET NULL,
    
    -- Organización que otorga acceso
    organizacion_id UUID NOT NULL REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,
    
    -- Permisos: VIEW, GET_PRESIGNED_URL, SHARE
    permiso VARCHAR(50) NOT NULL DEFAULT 'VIEW',
    
    -- Validez temporal (opcional)
    expires_at TIMESTAMPTZ,
    
    -- Auditoría
    razon_acceso VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    
    CHECK (grantee_usuario_uuid IS NOT NULL OR grantee_grupo_id IS NOT NULL),
    UNIQUE(media_id, grantee_usuario_uuid, permiso),
    UNIQUE(media_id, grantee_grupo_id, permiso)
);

CREATE INDEX idx_media_policy_usuario 
    ON core.media_access_policy(grantee_usuario_uuid) 
    WHERE revoked_at IS NULL;
CREATE INDEX idx_media_policy_grupo 
    ON core.media_access_policy(grantee_grupo_id) 
    WHERE revoked_at IS NULL;
CREATE INDEX idx_media_policy_media 
    ON core.media_access_policy(media_id) 
    WHERE revoked_at IS NULL;
CREATE INDEX idx_media_policy_org 
    ON core.media_access_policy(organizacion_id, created_at DESC);

-- 4. TABLA: Compartir media_assets entre organizaciones
-- Para cuando una organización (cedente) comparte facturas con otra (financiadora)
CREATE TABLE IF NOT EXISTS core.media_cross_org_sharing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL REFERENCES media.media_assets(id) ON DELETE CASCADE,
    
    -- Organización propietaria del asset
    owner_organizacion_id UUID NOT NULL REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,
    
    -- Organización receptora de acceso
    recipient_organizacion_id UUID NOT NULL REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,
    
    -- Quién otorgó el acceso
    granted_by_usuario_uuid UUID NOT NULL REFERENCES core.usuario(usuario_uuid) ON DELETE SET NULL,
    
    -- Nivel de acceso
    access_level VARCHAR(50) NOT NULL DEFAULT 'VIEW', -- VIEW, DOWNLOAD
    
    -- Rango de validez
    valid_from TIMESTAMPTZ DEFAULT now(),
    valid_until TIMESTAMPTZ,
    
    -- Auditoría
    razon_compartir TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    
    UNIQUE(media_id, owner_organizacion_id, recipient_organizacion_id, access_level),
    CONSTRAINT ck_cross_org_diferente CHECK (owner_organizacion_id != recipient_organizacion_id)
);

CREATE INDEX idx_media_cross_org_owner 
    ON core.media_cross_org_sharing(owner_organizacion_id, revoked_at);
CREATE INDEX idx_media_cross_org_recipient 
    ON core.media_cross_org_sharing(recipient_organizacion_id, revoked_at);
CREATE INDEX idx_media_cross_org_media 
    ON core.media_cross_org_sharing(media_id) WHERE revoked_at IS NULL;

-- 5. TABLA: Auditoría de acceso a media
CREATE TABLE IF NOT EXISTS core.media_access_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL REFERENCES media.media_assets(id) ON DELETE CASCADE,
    usuario_uuid UUID NOT NULL REFERENCES core.usuario(usuario_uuid) ON DELETE CASCADE,
    organizacion_id UUID NOT NULL REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,
    
    accion VARCHAR(50) NOT NULL, -- VIEW, DOWNLOAD, SHARE, DELETE
    ip_address VARCHAR(64),
    user_agent TEXT,
    correlation_id VARCHAR(255),
    
    accessed_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_media_audit_media 
    ON core.media_access_audit(media_id, accessed_at DESC);
CREATE INDEX idx_media_audit_usuario 
    ON core.media_access_audit(usuario_uuid, accessed_at DESC);
CREATE INDEX idx_media_audit_org 
    ON core.media_access_audit(organizacion_id, accessed_at DESC);

-- 6. FUNCIONES DE VERIFICACIÓN DE PERMISOS

-- Verificar si un usuario tiene permiso para ver un media_asset
CREATE OR REPLACE FUNCTION core.check_media_access(
    p_media_id UUID,
    p_usuario_uuid UUID,
    p_permiso VARCHAR(50) DEFAULT 'VIEW'
) RETURNS BOOLEAN AS $$
DECLARE
    v_org_id BIGINT;
    v_usuario_org_id BIGINT;
    v_has_direct_access BOOLEAN;
    v_has_group_access BOOLEAN;
    v_has_cross_org_access BOOLEAN;
    v_is_owner BOOLEAN;
BEGIN
    -- 1. Obtener organización del usuario
    SELECT u.usuario_id, u.usuario_uuid 
    FROM core.usuario u
    WHERE u.usuario_uuid = p_usuario_uuid
    INTO v_usuario_org_id;
    
    IF v_usuario_org_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- 2. Verificar si es propietario del media_asset
    SELECT EXISTS(
        SELECT 1 
        FROM core.media_asset_owner mao
        WHERE mao.media_id = p_media_id 
          AND mao.owner_usuario_uuid = p_usuario_uuid
    ) INTO v_is_owner;
    
    IF v_is_owner THEN
        RETURN TRUE;
    END IF;

    -- 3. Verificar acceso directo (usuario individual)
    SELECT EXISTS(
        SELECT 1 
        FROM core.media_access_policy map
        WHERE map.media_id = p_media_id 
          AND map.grantee_usuario_uuid = p_usuario_uuid
          AND map.permiso = p_permiso
          AND map.revoked_at IS NULL
          AND (map.expires_at IS NULL OR map.expires_at > NOW())
    ) INTO v_has_direct_access;
    
    IF v_has_direct_access THEN
        RETURN TRUE;
    END IF;

    -- 4. Verificar acceso por grupo de trabajo
    SELECT EXISTS(
        SELECT 1 
        FROM core.media_access_policy map
        JOIN core.grupo_miembro gm ON gm.grupo_id = map.grantee_grupo_id
        WHERE map.media_id = p_media_id 
          AND gm.usuario_uuid = p_usuario_uuid
          AND map.permiso = p_permiso
          AND map.revoked_at IS NULL
          AND gm.active = true
          AND (map.expires_at IS NULL OR map.expires_at > NOW())
    ) INTO v_has_group_access;
    
    IF v_has_group_access THEN
        RETURN TRUE;
    END IF;

    -- 5. Verificar acceso cross-org (compartir entre organizaciones)
    SELECT EXISTS(
        SELECT 1 
        FROM core.media_cross_org_sharing mcos
        JOIN core.media_asset_owner mao ON mao.media_id = mcos.media_id
        JOIN core.usuario u ON u.usuario_uuid = p_usuario_uuid
        JOIN core.usuario u_owner ON u_owner.usuario_id = mao.organizacion_id -- relación usuario->org
        WHERE mcos.media_id = p_media_id 
          AND mcos.access_level = p_permiso
          AND mcos.revoked_at IS NULL
          AND (mcos.valid_until IS NULL OR mcos.valid_until > NOW())
          AND mcos.valid_from <= NOW()
    ) INTO v_has_cross_org_access;
    
    RETURN v_has_cross_org_access;
END;
$$ LANGUAGE plpgsql STABLE;

-- Función para registrar acceso (auditoría)
CREATE OR REPLACE FUNCTION core.log_media_access(
    p_media_id UUID,
    p_usuario_uuid UUID,
    p_organizacion_id UUID,
    p_accion VARCHAR(50),
    p_ip_address VARCHAR(64) DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_correlation_id VARCHAR(255) DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_audit_id UUID;
BEGIN
    INSERT INTO core.media_access_audit (
        media_id, usuario_uuid, organizacion_id, accion, 
        ip_address, user_agent, correlation_id
    ) VALUES (
        p_media_id, p_usuario_uuid, p_organizacion_id, p_accion,
        p_ip_address, p_user_agent, p_correlation_id
    )
    RETURNING id INTO v_audit_id;
    
    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql;

-- 7. TRIGGER: Evitar revocar permisos de propietarios
CREATE OR REPLACE FUNCTION core.tr_protect_owner_permissions()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.revoked_at IS NOT NULL AND OLD.revoked_at IS NULL THEN
        -- Verificar si el grantee es propietario
        IF EXISTS(
            SELECT 1 
            FROM core.media_asset_owner 
            WHERE media_id = NEW.media_id 
              AND owner_usuario_uuid = NEW.grantee_usuario_uuid
        ) THEN
            RAISE EXCEPTION 'No se pueden revocar permisos al propietario del asset';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_media_access_protect_owner
BEFORE UPDATE ON core.media_access_policy
FOR EACH ROW
EXECUTE PROCEDURE core.tr_protect_owner_permissions();

-- 8. PERMISOS DE ACCESO
GRANT ALL PRIVILEGES ON SCHEMA core TO desarrollo;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA core TO desarrollo;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA core TO desarrollo;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA core TO desarrollo;
