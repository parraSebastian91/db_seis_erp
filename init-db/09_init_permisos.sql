-- =============================================================================
-- ESQUEMA: permisos
-- Capa genérica de control de acceso (ABAC) para cualquier recurso del sistema.
-- Diseño: resource_type + resource_id polimórfico.
--
-- RECURSOS SOPORTADOS (catálogo inicial):
--   MEDIA_ASSET     → media.media_assets(id)
--   FACTURA         → factura.factura(id)
--   OFERTA          → factura.ofertas(id)
--   QUERY_FACTURA   → permisos lógicos sobre endpoints/queries de facturas
--
-- COMO AGREGAR UN NUEVO RECURSO:
--   1. INSERT INTO permisos.resource_catalog (code, descripcion) VALUES ('MI_RECURSO', '...');
--   2. Insertar filas en permisos.resource_owner / permisos.access_policy / permisos.user_whitelist con ese code.
--   3. Llamar permisos.check_access('MI_RECURSO', <id>, <usuario>, <permiso>).
--   No requiere nuevas tablas.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS permisos;

CREATE TYPE permisos.permiso_tipo AS ENUM (
    'VIEW',
    'DELETE',
    'CREATE',
    'UPDATE'
);

-- =========================================================
-- 1. CATÁLOGO DE TIPOS DE RECURSO
-- =========================================================
CREATE TABLE IF NOT EXISTS permisos.resource_catalog (
    code        VARCHAR(80)  PRIMARY KEY,                -- MEDIA_ASSET, FACTURA, OFERTA…
    descripcion VARCHAR(255) NOT NULL,
    activo      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO permisos.resource_catalog (code, descripcion) VALUES
    ('MEDIA_ASSET',   'Archivos y documentos almacenados en el sistema de media'),
    ('FACTURA',       'Facturas emitidas y publicadas en el mercado'),
    ('OFERTA',        'Ofertas de financiamiento sobre facturas'),
    ('QUERY_FACTURA', 'Permiso lógico para ejecutar consultas sobre facturas'),
    ('HISTORIAL_NEGOCIO', 'Acceso al historial de operaciones entre empresas')
ON CONFLICT (code) DO NOTHING;

-- =========================================================
-- 2. PROPIETARIOS DE RECURSO
-- Quién "posee" una instancia de un recurso.
-- =========================================================
CREATE TABLE IF NOT EXISTS permisos.resource_owner (
    id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_type        VARCHAR(80) NOT NULL REFERENCES permisos.resource_catalog(code),
    resource_id          UUID        NOT NULL,
    owner_usuario_uuid   UUID        NOT NULL REFERENCES core.usuario(usuario_uuid)   ON DELETE CASCADE,
    organizacion_id      UUID        NOT NULL REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,
    es_propietario_principal BOOLEAN NOT NULL DEFAULT FALSE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (resource_type, resource_id, owner_usuario_uuid)
);

CREATE INDEX idx_perm_owner_usuario
    ON permisos.resource_owner (owner_usuario_uuid);
CREATE INDEX idx_perm_owner_resource
    ON permisos.resource_owner (resource_type, resource_id);
CREATE INDEX idx_perm_owner_org
    ON permisos.resource_owner (organizacion_id);

-- =========================================================
-- 3. POLÍTICAS DE ACCESO (intra-organización)
-- Qué usuario o grupo puede hacer qué sobre qué recurso.
-- =========================================================
CREATE TABLE IF NOT EXISTS permisos.access_policy (
    id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_type        VARCHAR(80) NOT NULL REFERENCES permisos.resource_catalog(code),
    resource_id          UUID,                      -- NULL = aplica a TODOS los recursos de ese tipo en la org

    -- Quién recibe el permiso
    grantee_usuario_uuid UUID        REFERENCES core.usuario(usuario_uuid)     ON DELETE CASCADE,
    grantee_grupo_id     UUID        REFERENCES core.grupo_trabajo(grupo_id)   ON DELETE CASCADE,

    -- Quién otorga el permiso
    granter_usuario_uuid UUID        NOT NULL REFERENCES core.usuario(usuario_uuid) ON DELETE SET NULL,

    -- Organización en la que aplica el permiso
    organizacion_id      UUID        NOT NULL REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,

    -- Permiso concreto: VIEW, DOWNLOAD, EDIT, SHARE, QUERY, EXPORT …
    permiso              VARCHAR(80) NOT NULL DEFAULT 'VIEW',

    -- Validez temporal
    expires_at           TIMESTAMPTZ,

    -- Auditoría
    razon_acceso         VARCHAR(255),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at           TIMESTAMPTZ,

    CONSTRAINT ck_perm_grantee CHECK (grantee_usuario_uuid IS NOT NULL OR grantee_grupo_id IS NOT NULL),
    UNIQUE (resource_type, resource_id, grantee_usuario_uuid, permiso),
    UNIQUE (resource_type, resource_id, grantee_grupo_id,    permiso)
);

CREATE INDEX idx_perm_policy_usuario
    ON permisos.access_policy (grantee_usuario_uuid)
    WHERE revoked_at IS NULL;
CREATE INDEX idx_perm_policy_grupo
    ON permisos.access_policy (grantee_grupo_id)
    WHERE revoked_at IS NULL;
CREATE INDEX idx_perm_policy_resource
    ON permisos.access_policy (resource_type, resource_id)
    WHERE revoked_at IS NULL;
CREATE INDEX idx_perm_policy_org
    ON permisos.access_policy (organizacion_id, resource_type);
-- Política de tipo global (sin resource_id específico)
CREATE INDEX idx_perm_policy_global
    ON permisos.access_policy (resource_type, organizacion_id, permiso)
    WHERE resource_id IS NULL AND revoked_at IS NULL;

-- =========================================================
-- 3.B LISTA BLANCA DE USUARIOS (cross-org / fuera de grupos)
-- Permite otorgar acceso explícito a usuarios puntuales, aunque
-- no pertenezcan a un grupo de trabajo o a la misma organización.
-- =========================================================
CREATE TABLE IF NOT EXISTS permisos.user_whitelist (
    id                       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_type            VARCHAR(80) NOT NULL REFERENCES permisos.resource_catalog(code),
    resource_id              UUID,       -- NULL = permiso global por tipo de recurso
    allowed_usuario_uuid     UUID        NOT NULL REFERENCES core.usuario(usuario_uuid) ON DELETE CASCADE,
    granted_by_usuario_uuid  UUID        REFERENCES core.usuario(usuario_uuid) ON DELETE SET NULL,
    source_organizacion_id   UUID        REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,
    permiso                  VARCHAR(80) NOT NULL DEFAULT 'VIEW',
    expires_at               TIMESTAMPTZ,
    razon_acceso             VARCHAR(255),
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at               TIMESTAMPTZ,
    UNIQUE (resource_type, resource_id, allowed_usuario_uuid, permiso)
);

CREATE INDEX idx_perm_whitelist_usuario
    ON permisos.user_whitelist (allowed_usuario_uuid)
    WHERE revoked_at IS NULL;
CREATE INDEX idx_perm_whitelist_resource
    ON permisos.user_whitelist (resource_type, resource_id)
    WHERE revoked_at IS NULL;

-- =========================================================
-- 4. COMPARTIR ENTRE ORGANIZACIONES
-- Una organización propietaria comparte acceso a un recurso con otra.
-- =========================================================
CREATE TABLE IF NOT EXISTS permisos.cross_org_sharing (
    id                       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_type            VARCHAR(80) NOT NULL REFERENCES permisos.resource_catalog(code),
    resource_id              UUID        NOT NULL,
    owner_organizacion_id    UUID        NOT NULL REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,
    recipient_organizacion_id UUID       NOT NULL REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,
    granted_by_usuario_uuid  UUID        NOT NULL REFERENCES core.usuario(usuario_uuid)           ON DELETE SET NULL,
    access_level             VARCHAR(80) NOT NULL DEFAULT 'VIEW',
    valid_from               TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until              TIMESTAMPTZ,
    razon_compartir          TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at               TIMESTAMPTZ,
    UNIQUE (resource_type, resource_id, owner_organizacion_id, recipient_organizacion_id, access_level),
    CONSTRAINT ck_cross_org_diferente CHECK (owner_organizacion_id != recipient_organizacion_id)
);

CREATE INDEX idx_perm_cross_owner
    ON permisos.cross_org_sharing (owner_organizacion_id, revoked_at);
CREATE INDEX idx_perm_cross_recipient
    ON permisos.cross_org_sharing (recipient_organizacion_id, revoked_at);
CREATE INDEX idx_perm_cross_resource
    ON permisos.cross_org_sharing (resource_type, resource_id)
    WHERE revoked_at IS NULL;

-- =========================================================
-- 5. AUDITORÍA GENÉRICA DE ACCESO
-- =========================================================
CREATE TABLE IF NOT EXISTS permisos.access_audit (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_type  VARCHAR(80) NOT NULL,
    resource_id    UUID        NOT NULL,
    usuario_uuid   UUID        NOT NULL REFERENCES core.usuario(usuario_uuid)     ON DELETE CASCADE,
    organizacion_id UUID       NOT NULL REFERENCES core.organizacion(organizacion_uuid) ON DELETE CASCADE,
    accion         VARCHAR(80) NOT NULL,    -- VIEW, DOWNLOAD, QUERY, SHARE, DENY …
    resultado      VARCHAR(20) NOT NULL DEFAULT 'ALLOWED', -- ALLOWED, DENIED
    ip_address     VARCHAR(64),
    user_agent     TEXT,
    correlation_id UUID,
    accessed_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_perm_audit_resource
    ON permisos.access_audit (resource_type, resource_id, accessed_at DESC);
CREATE INDEX idx_perm_audit_usuario
    ON permisos.access_audit (usuario_uuid, accessed_at DESC);
CREATE INDEX idx_perm_audit_org
    ON permisos.access_audit (organizacion_id, accessed_at DESC);
CREATE INDEX idx_perm_audit_denied
    ON permisos.access_audit (resultado, accessed_at DESC)
    WHERE resultado = 'DENIED';

-- =========================================================
-- 6. FUNCIÓN GENÉRICA: check_access
-- Evalúa si un usuario tiene permiso sobre un recurso.
-- Jerarquía: propietario > política directa > política por grupo > cross-org.
-- =========================================================
CREATE OR REPLACE FUNCTION permisos.check_access(
    p_resource_type  VARCHAR(80),
    p_resource_id    UUID,
    p_usuario_uuid   UUID,
    p_permiso        VARCHAR(80) DEFAULT 'VIEW',
    p_organizacion_id UUID       DEFAULT NULL  -- si se pasa, restringe el cross-org check
) RETURNS BOOLEAN AS $$
DECLARE
    v_usuario_existe BOOLEAN;
BEGIN
    -- 0. Verificar que el usuario existe
    SELECT EXISTS (
        SELECT 1 FROM core.usuario WHERE usuario_uuid = p_usuario_uuid
    ) INTO v_usuario_existe;

    IF NOT v_usuario_existe THEN
        RETURN FALSE;
    END IF;

    -- 1. ¿Es propietario?
    IF EXISTS (
        SELECT 1 FROM permisos.resource_owner
        WHERE resource_type = p_resource_type
          AND resource_id    = p_resource_id
          AND owner_usuario_uuid = p_usuario_uuid
    ) THEN
        RETURN TRUE;
    END IF;

    -- 2. ¿Política directa activa sobre recurso específico?
    IF EXISTS (
        SELECT 1 FROM permisos.access_policy
        WHERE resource_type        = p_resource_type
          AND resource_id          = p_resource_id
          AND grantee_usuario_uuid = p_usuario_uuid
          AND permiso              = p_permiso
          AND revoked_at IS NULL
          AND (expires_at IS NULL OR expires_at > NOW())
    ) THEN
        RETURN TRUE;
    END IF;

    -- 3. ¿Política global sobre el tipo de recurso en la organización?
    IF p_organizacion_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM permisos.access_policy
        WHERE resource_type        = p_resource_type
          AND resource_id          IS NULL
          AND grantee_usuario_uuid = p_usuario_uuid
          AND organizacion_id      = p_organizacion_id
          AND permiso              = p_permiso
          AND revoked_at IS NULL
          AND (expires_at IS NULL OR expires_at > NOW())
    ) THEN
        RETURN TRUE;
    END IF;

    -- 3.B ¿Usuario en lista blanca explícita?
    IF EXISTS (
        SELECT 1 FROM permisos.user_whitelist uw
        WHERE uw.resource_type        = p_resource_type
          AND (uw.resource_id         = p_resource_id OR uw.resource_id IS NULL)
          AND uw.allowed_usuario_uuid = p_usuario_uuid
          AND uw.permiso              = p_permiso
          AND uw.revoked_at           IS NULL
          AND (uw.expires_at          IS NULL OR uw.expires_at > NOW())
          AND (
                p_organizacion_id IS NULL
                OR uw.source_organizacion_id IS NULL
                OR uw.source_organizacion_id = p_organizacion_id
          )
    ) THEN
        RETURN TRUE;
    END IF;

    -- 4. ¿Acceso por grupo de trabajo?
    IF EXISTS (
        SELECT 1 FROM permisos.access_policy ap
        JOIN core.grupo_miembro gm ON gm.grupo_id = ap.grantee_grupo_id
        WHERE ap.resource_type  = p_resource_type
          AND (ap.resource_id   = p_resource_id OR ap.resource_id IS NULL)
          AND gm.usuario_uuid   = p_usuario_uuid
          AND ap.permiso        = p_permiso
          AND ap.revoked_at     IS NULL
          AND gm.active         = TRUE
          AND (ap.expires_at    IS NULL OR ap.expires_at > NOW())
    ) THEN
        RETURN TRUE;
    END IF;

    -- 5. ¿Acceso cross-org vigente?
    IF p_organizacion_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM permisos.cross_org_sharing cos
        WHERE cos.resource_type              = p_resource_type
          AND cos.resource_id                = p_resource_id
          AND cos.recipient_organizacion_id  = p_organizacion_id
          AND cos.access_level               = p_permiso
          AND cos.revoked_at                 IS NULL
          AND cos.valid_from                 <= NOW()
          AND (cos.valid_until               IS NULL OR cos.valid_until > NOW())
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE;

-- =========================================================
-- 7. FUNCIÓN: log_access
-- Registrar un intento de acceso (permitido o denegado).
-- =========================================================
CREATE OR REPLACE FUNCTION permisos.log_access(
    p_resource_type   VARCHAR(80),
    p_resource_id     UUID,
    p_usuario_uuid    UUID,
    p_organizacion_id UUID,
    p_accion          VARCHAR(80),
    p_resultado       VARCHAR(20) DEFAULT 'ALLOWED',
    p_ip_address      VARCHAR(64) DEFAULT NULL,
    p_user_agent      TEXT        DEFAULT NULL,
    p_correlation_id  UUID        DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO permisos.access_audit (
        resource_type, resource_id, usuario_uuid, organizacion_id,
        accion, resultado, ip_address, user_agent, correlation_id
    ) VALUES (
        p_resource_type, p_resource_id, p_usuario_uuid, p_organizacion_id,
        p_accion, p_resultado, p_ip_address, p_user_agent, p_correlation_id
    )
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 7.B FUNCIÓN: get_asset_storage_key
-- Devuelve la storage key (url_path en MinIO) de un asset.
-- Valida el permiso del usuario ANTES de entregar la key y
-- registra el intento en permisos.access_audit (ALLOWED o DENIED).
--
-- Lógica de permiso:
--   Si el asset es adjunto de una factura → valida 'FACTURA' VIEW
--   Si es un asset standalone              → valida 'MEDIA_ASSET' VIEW
--
-- Parámetros:
--   p_asset_id        → media.media_assets.id (= factura_adjuntos.asset_id)
--   p_usuario_uuid    → usuario que solicita el acceso
--   p_organizacion_id → organización del usuario (contexto del permiso)
--   p_accion          → etiqueta del intento (ej: 'DOWNLOAD', 'VIEW_VISOR')
--   p_ip_address      → IP del cliente (para auditoría)
--   p_correlation_id  → correlation_id de la request HTTP
--   p_user_agent      → User-Agent del cliente
--
-- Retorna:
--   storage_key → url_path del media_variant más reciente (NULL si denegado)
--   audit_id    → UUID del registro en permisos.access_audit
-- =========================================================
CREATE OR REPLACE FUNCTION permisos.get_asset_storage_key(
    p_asset_id        UUID,
    p_usuario_uuid    UUID,
    p_organizacion_id UUID,
    p_accion          VARCHAR(80) DEFAULT 'VIEW',
    p_ip_address      VARCHAR(64) DEFAULT NULL,
    p_correlation_id  UUID        DEFAULT NULL,
    p_user_agent      TEXT        DEFAULT NULL
) RETURNS TABLE (
    storage_key  TEXT,   -- object key en el bucket MinIO (url_path de media_variants)
    audit_id     UUID    -- ID del registro de auditoría creado
) AS $$
DECLARE
    v_tiene_permiso  BOOLEAN    := FALSE;
    v_storage_key    TEXT       := NULL;
    v_resultado      VARCHAR(20);
    v_audit_id       UUID;
    v_factura_id     UUID;
    v_resource_type  VARCHAR(80);
    v_resource_id    UUID;
BEGIN
    -- ── 1. Resolver el contexto de permiso ───────────────────────────────────
    -- Busca si el asset está vinculado a una factura (es un adjunto documental).
    -- Si lo es, el permiso se valida contra la FACTURA, no contra el asset directo.
    SELECT fa.factura_id INTO v_factura_id
    FROM factura.factura_adjuntos fa
    WHERE fa.asset_id = p_asset_id
    LIMIT 1;

    IF v_factura_id IS NOT NULL THEN
        -- Adjunto de factura: verifica que el usuario tenga VIEW sobre la factura
        v_resource_type := 'FACTURA';
        v_resource_id   := v_factura_id;
    ELSE
        -- Asset standalone (avatar, banner, etc.): verifica MEDIA_ASSET directamente
        v_resource_type := 'MEDIA_ASSET';
        v_resource_id   := p_asset_id;
    END IF;

    -- ── 2. Validar permiso ───────────────────────────────────────────────────
    v_tiene_permiso := permisos.check_access(
        v_resource_type,
        v_resource_id,
        p_usuario_uuid,
        'VIEW',
        p_organizacion_id
    );

    -- ── 3. Obtener la key solo si tiene permiso ──────────────────────────────
    IF v_tiene_permiso THEN
        -- REGEXP_REPLACE normaliza espacios → '_' para cubrir el caso en que el
        -- worker guardó el nombre original (con espacios) pero MinIO recibió la
        -- clave sanitizada (con guiones bajos). Defensa en profundidad.
        SELECT REGEXP_REPLACE(mv.url_path, '\s+', '_', 'g') INTO v_storage_key
        FROM media.media_variants mv
        WHERE mv.asset_id = p_asset_id
        ORDER BY mv.created_at DESC NULLS LAST
        LIMIT 1;

        v_resultado := 'ALLOWED';
    ELSE
        v_resultado := 'DENIED';
    END IF;

    -- ── 4. Registrar el intento (siempre, sea ALLOWED o DENIED) ─────────────
    v_audit_id := permisos.log_access(
        v_resource_type,
        v_resource_id,
        p_usuario_uuid,
        p_organizacion_id,
        p_accion,
        v_resultado,
        p_ip_address,
        p_user_agent,
        p_correlation_id
    );

    RETURN QUERY SELECT v_storage_key, v_audit_id;
END;
$$ LANGUAGE plpgsql;
-- Otorga acceso explícito a un usuario (idempotente).
-- Útil para usuarios fuera de grupo de trabajo o cross-org.
-- =========================================================
CREATE OR REPLACE FUNCTION permisos.grant_user_whitelist_access(
    p_resource_type           VARCHAR(80),
    p_resource_id             UUID,
    p_allowed_usuario_uuid    UUID,
    p_granted_by_usuario_uuid UUID,
    p_permiso                 VARCHAR(80) DEFAULT 'VIEW',
    p_razon                   VARCHAR(255) DEFAULT NULL,
    p_expires_at              TIMESTAMPTZ DEFAULT NULL,
    p_source_organizacion_id  UUID        DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO permisos.user_whitelist (
        resource_type,
        resource_id,
        allowed_usuario_uuid,
        granted_by_usuario_uuid,
        source_organizacion_id,
        permiso,
        razon_acceso,
        expires_at
    ) VALUES (
        p_resource_type,
        p_resource_id,
        p_allowed_usuario_uuid,
        p_granted_by_usuario_uuid,
        p_source_organizacion_id,
        p_permiso,
        p_razon,
        p_expires_at
    )
    ON CONFLICT (resource_type, resource_id, allowed_usuario_uuid, permiso)
    DO UPDATE SET
        revoked_at            = NULL,
        expires_at            = EXCLUDED.expires_at,
        razon_acceso          = EXCLUDED.razon_acceso,
        source_organizacion_id = EXCLUDED.source_organizacion_id
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 11.B FUNCIÓN: revoke_user_whitelist_access
-- Revoca acceso explícito de lista blanca sin borrar historial.
-- =========================================================
CREATE OR REPLACE FUNCTION permisos.revoke_user_whitelist_access(
    p_resource_type        VARCHAR(80),
    p_resource_id          UUID,
    p_allowed_usuario_uuid UUID,
    p_permiso              VARCHAR(80) DEFAULT 'VIEW'
) RETURNS BOOLEAN AS $$
DECLARE
    v_rows_updated INT;
BEGIN
    UPDATE permisos.user_whitelist
    SET revoked_at = NOW()
    WHERE resource_type        = p_resource_type
      AND resource_id          = p_resource_id
      AND allowed_usuario_uuid = p_allowed_usuario_uuid
      AND permiso              = p_permiso
      AND revoked_at           IS NULL;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    RETURN v_rows_updated > 0;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 8. FUNCIÓN: grant_access
-- Conceder un permiso de forma segura (idempotente).
-- =========================================================
CREATE OR REPLACE FUNCTION permisos.grant_access(
    p_resource_type        VARCHAR(80),
    p_resource_id          UUID,        -- NULL = permiso global sobre el tipo
    p_grantee_usuario_uuid UUID,
    p_granter_usuario_uuid UUID,
    p_organizacion_id      UUID,
    p_permiso              VARCHAR(80) DEFAULT 'VIEW',
    p_razon                VARCHAR(255) DEFAULT NULL,
    p_expires_at           TIMESTAMPTZ DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO permisos.access_policy (
        resource_type, 
        resource_id,
        grantee_usuario_uuid, 
        granter_usuario_uuid,
        organizacion_id, 
        permiso, 
        razon_acceso,
        expires_at
    ) VALUES (
        p_resource_type, 
        p_resource_id,
        p_grantee_usuario_uuid, 
        p_granter_usuario_uuid,
        p_organizacion_id, 
        p_permiso, 
        p_razon, 
        p_expires_at
    )
    ON CONFLICT (resource_type, resource_id, grantee_usuario_uuid, permiso)
    DO UPDATE SET
        revoked_at   = NULL,
        expires_at   = EXCLUDED.expires_at,
        razon_acceso = EXCLUDED.razon_acceso
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 9. FUNCIÓN: revoke_access
-- Revocar un permiso sin borrar el registro histórico.
-- =========================================================
CREATE OR REPLACE FUNCTION permisos.revoke_access(
    p_resource_type        VARCHAR(80),
    p_resource_id          UUID,
    p_grantee_usuario_uuid UUID,
    p_permiso              VARCHAR(80) DEFAULT 'VIEW'
) RETURNS BOOLEAN AS $$
DECLARE
    v_rows_updated INT;
BEGIN
    UPDATE permisos.access_policy
    SET revoked_at = NOW()
    WHERE resource_type        = p_resource_type
      AND resource_id          = p_resource_id
      AND grantee_usuario_uuid = p_grantee_usuario_uuid
      AND permiso              = p_permiso
      AND revoked_at           IS NULL;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    RETURN v_rows_updated > 0;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 10. FUNCIÓN: grant_access_to_organization_groups
-- Otorga permiso a TODOS los grupos de trabajo activos de una organización.
-- Útil para: "Que todos los financiadores vean esta factura"
--
-- Parámetros:
--   p_resource_type:      tipo de recurso (ej: 'FACTURA')
--   p_resource_id:        ID del recurso (ej: factura UUID)
--   p_target_org_id:      organización cuyos grupos recibirán acceso (ej: org FINANCIERA)
--   p_granter_usuario_uuid: quién otorga el permiso
--   p_permiso:            el permiso a otorgar (default: 'VIEW')
--   p_razon:              motivo del acceso (opcional)
--
-- Retorna: número de permisos otorgados (grupos activos en la org)
-- =========================================================
CREATE OR REPLACE FUNCTION permisos.grant_access_to_organization_groups(
    p_resource_type        VARCHAR(80),
    p_resource_id          UUID,
    p_target_org_id        UUID,
    p_granter_usuario_uuid UUID,
    p_permiso              VARCHAR(80) DEFAULT 'VIEW',
    p_razon                VARCHAR(255) DEFAULT NULL
) RETURNS INT AS $$
DECLARE
    v_grupo_id UUID;
    v_count INT := 0;
BEGIN
    -- Iterar sobre todos los grupos activos de la organización
    FOR v_grupo_id IN
        SELECT grupo_id
        FROM core.grupo_trabajo
        WHERE organizacion_id = p_target_org_id
          AND activo = TRUE
    LOOP
        -- Insertar o actualizar el permiso para cada grupo
        INSERT INTO permisos.access_policy (
            resource_type,
            resource_id,
            grantee_grupo_id,
            granter_usuario_uuid,
            organizacion_id,
            permiso,
            razon_acceso
        ) VALUES (
            p_resource_type,
            p_resource_id,
            v_grupo_id,
            p_granter_usuario_uuid,
            p_target_org_id,
            p_permiso,
            p_razon
        )
        ON CONFLICT (resource_type, resource_id, grantee_grupo_id, permiso)
        DO UPDATE SET
            revoked_at   = NULL,
            razon_acceso = EXCLUDED.razon_acceso;

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 10.B FUNCIÓN: revoke_access_from_organization_groups
-- Revoca el permiso de TODOS los grupos de trabajo activos de una organización
-- sobre un recurso específico. Imagen espejo de grant_access_to_organization_groups.
--
-- Parámetros:
--   p_resource_type:   tipo de recurso (ej: 'FACTURA')
--   p_resource_id:     ID del recurso (ej: factura UUID)
--   p_target_org_id:   organización cuyos grupos perderán el acceso
--   p_permiso:         el permiso a revocar (default: 'VIEW')
--
-- Retorna: número de políticas revocadas (grupos afectados)
-- =========================================================
CREATE OR REPLACE FUNCTION permisos.revoke_access_from_organization_groups(
    p_resource_type VARCHAR(80),
    p_resource_id   UUID,
    p_target_org_id UUID,
    p_permiso       VARCHAR(80) DEFAULT 'VIEW'
) RETURNS INT AS $$
DECLARE
    v_rows_updated INT := 0;
BEGIN
    UPDATE permisos.access_policy ap
    SET revoked_at = NOW()
    FROM core.grupo_trabajo gt
    WHERE gt.grupo_id        = ap.grantee_grupo_id
      AND gt.organizacion_id = p_target_org_id
      AND gt.activo          = TRUE
      AND ap.resource_type   = p_resource_type
      AND ap.resource_id     = p_resource_id
      AND ap.permiso         = p_permiso
      AND ap.revoked_at      IS NULL;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    RETURN v_rows_updated;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 12. TRIGGER: auto-registrar propietario al crear una factura
-- Cuando se inserta una factura:
--   - El gestor queda como propietario principal (es_propietario_principal = TRUE).
--   - Su jefe directo (resuelto vía core.grupo_miembro.jefe_directo_id)
--     queda registrado como co-propietario (es_propietario_principal = FALSE).
-- Si el gestor pertenece a varios grupos, se registra cada jefe distinto una vez.
-- =========================================================
CREATE OR REPLACE FUNCTION permisos.fn_auto_register_factura_owner()
RETURNS TRIGGER AS $$
DECLARE
    v_jefe_uuid      UUID;
    v_jefe_org_id    UUID;
BEGIN
    -- Guard: factura sin gestor asignado no puede registrar propietario
    IF NEW.gestor_usuario_uuid IS NULL THEN
        RETURN NEW;
    END IF;

    -- 1. Registrar al gestor como propietario principal
    INSERT INTO permisos.resource_owner (
        resource_type,
        resource_id,
        owner_usuario_uuid,
        organizacion_id,
        es_propietario_principal
    ) VALUES (
        'FACTURA',
        NEW.id,
        NEW.gestor_usuario_uuid,
        NEW.organizacion_id,
        TRUE
    )
    ON CONFLICT (resource_type, resource_id, owner_usuario_uuid) DO NOTHING;

    -- 2. Registrar al jefe directo de cada grupo donde el gestor es miembro activo
    --    jefe_directo_id → miembro_id del jefe → su usuario_uuid
    FOR v_jefe_uuid, v_jefe_org_id IN
        SELECT DISTINCT
            jm_jefe.usuario_uuid,
            gt.organizacion_id
        FROM core.grupo_miembro gm_gestor
        JOIN core.grupo_miembro jm_jefe
            ON jm_jefe.miembro_id = gm_gestor.jefe_directo_id
           AND jm_jefe.active = TRUE
        JOIN core.grupo_trabajo gt
            ON gt.grupo_id = gm_gestor.grupo_id
           AND gt.activo = TRUE
        WHERE gm_gestor.usuario_uuid = NEW.gestor_usuario_uuid
          AND gm_gestor.active = TRUE
          AND gm_gestor.jefe_directo_id IS NOT NULL
          -- No re-registrar si el jefe es el mismo gestor (dato inválido, pero seguro)
          AND jm_jefe.usuario_uuid <> NEW.gestor_usuario_uuid
    LOOP
        INSERT INTO permisos.resource_owner (
            resource_type,
            resource_id,
            owner_usuario_uuid,
            organizacion_id,
            es_propietario_principal
        ) VALUES (
            'FACTURA',
            NEW.id,
            v_jefe_uuid,
            v_jefe_org_id,
            FALSE
        )
        ON CONFLICT (resource_type, resource_id, owner_usuario_uuid) DO NOTHING;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_factura_register_owner
    AFTER INSERT ON factura.factura
    FOR EACH ROW
    EXECUTE FUNCTION permisos.fn_auto_register_factura_owner();

-- =========================================================
-- 12.B VISTAS PRÁCTICAS PARA REPORTING Y ACCESO A DATOS
-- =========================================================

-- Base reutilizable: facturas visibles en marketplace (publicadas/ofertadas)
-- Trae solo facturas con estado PUBLICADA u OFERTADA.
-- Incluye resumen de ofertas (total, enviadas, revisadas, aceptadas, rechazadas, mejor tasa, mejor monto).
CREATE OR REPLACE VIEW permisos.vw_facturas_publicadas_ofertadas_base AS
SELECT
    f.id AS factura_id,
    f.organizacion_id AS cedente_org_id,
    org.razon_social AS cedente_razon_social,
    CONCAT(org.rut,'-',org.dv) AS cedente_rut,
    f.deudor_nombre,
    f.deudor_rut,
    f.factura_numero,
    f.monto_total,
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
    u.userName as username,
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
    -- URL del adjunto principal (es_principal = TRUE) para el visor documental
    SELECT mv.url_path
    FROM factura.factura_adjuntos fa
    JOIN media.media_variants mv ON mv.asset_id = fa.asset_id
    WHERE fa.factura_id = f.id AND fa.es_principal = TRUE
    ORDER BY mv.created_at DESC NULLS LAST
    LIMIT 1
) mv ON TRUE
LEFT JOIN LATERAL (
    -- JSON array de todos los adjuntos con su URL resuelta desde media_variants
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
) adj ON TRUE
--WHERE f.status IN ('PUBLICADA', 'OFERTADA');

-- Devuelve únicamente facturas donde el usuario sí tiene VIEW.
-- Evalúa permisos con permisos.check_access para:
-- organización explícita (si la pasas),
-- organizaciones del usuario por grupos,
-- y fallback de organización cedente (para no perder visibilidad de propietario).

CREATE OR REPLACE FUNCTION permisos.obtener_facturas_accesibles(
    p_usuario_uuid UUID,
    p_organizacion_id UUID DEFAULT NULL
)
RETURNS TABLE (
    factura_id UUID,
    cedente_org_id UUID,
    cedente_razon_social VARCHAR,
    cedente_rut VARCHAR,
    deudor_nombre VARCHAR,
    deudor_rut VARCHAR,
    factura_numero VARCHAR,
    monto_total VARCHAR,
    fecha_vencimiento DATE,
    factura_status VARCHAR,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    total_ofertas BIGINT,
    ofertas_enviadas BIGINT,
    ofertas_revisadas BIGINT,
    ofertas_aceptadas BIGINT,
    ofertas_rechazadas BIGINT,
    mejor_tasa NUMERIC,
    mejor_monto_oferta NUMERIC,
    ultima_actualizacion_oferta TIMESTAMPTZ,
    esta_ofertada BOOLEAN,
    tiene_permiso BOOLEAN,
    org_contexto_uuid UUID,
    url_factura VARCHAR,
    gestor_uuid UUID,
    gestor_username VARCHAR,
    correlation_id UUID,
    adjuntos JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH orgs_usuario AS (
        SELECT DISTINCT gt.organizacion_id
        FROM core.grupo_miembro gm
        JOIN core.grupo_trabajo gt
            ON gt.grupo_id = gm.grupo_id
        WHERE gm.usuario_uuid = p_usuario_uuid
          AND gm.active = TRUE
          AND gt.activo = TRUE
    ),
    base AS (
        SELECT *
        FROM permisos.vw_facturas_publicadas_ofertadas_base
    )
    SELECT
        b.factura_id,
        b.cedente_org_id,
        b.cedente_razon_social,
        b.cedente_rut::VARCHAR,
        b.deudor_nombre,
        b.deudor_rut,
        b.factura_numero,
        b.monto_total,
        b.fecha_vencimiento,
        b.factura_status,
        b.created_at,
        b.updated_at,
        b.total_ofertas,
        b.ofertas_enviadas,
        b.ofertas_revisadas,
        b.ofertas_aceptadas,
        b.ofertas_rechazadas,
        b.mejor_tasa,
        b.mejor_monto_oferta,
        b.ultima_actualizacion_oferta,
        b.esta_ofertada,
        TRUE AS tiene_permiso,
        COALESCE(p_organizacion_id, b.cedente_org_id) AS org_contexto_uuid,
        COALESCE(b.url_path::VARCHAR, ''::VARCHAR) AS url_factura,
		b.gestor_uuid,
		b.username as gestor_username,
		b.correlation_id,
		b.adjuntos
    FROM base b
    WHERE EXISTS (
        SELECT 1
        FROM (
            SELECT p_organizacion_id AS org_id
            WHERE p_organizacion_id IS NOT NULL

            UNION

            SELECT o.organizacion_id
            FROM orgs_usuario o
            WHERE p_organizacion_id IS NULL

            UNION

            SELECT b.cedente_org_id
            WHERE p_organizacion_id IS NULL
        ) contexto
        WHERE permisos.check_access(
            'FACTURA',
            b.factura_id,
            p_usuario_uuid,
            'VIEW',
            contexto.org_id
        )
    )
    ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Vista por organización financiera (útil para paneles por org).
-- Muestra facturas publicadas/ofertadas donde existe al menos un permiso
-- VIEW activo para alguno de los grupos de esa organización.
CREATE OR REPLACE VIEW permisos.vw_facturas_accesibles_por_org AS
SELECT
    b.*,
    gt.organizacion_id AS financiera_org_id,
    COUNT(DISTINCT ap.id) AS total_politicas_view_activas
FROM permisos.vw_facturas_publicadas_ofertadas_base b
JOIN permisos.access_policy ap
    ON ap.resource_type = 'FACTURA'
   AND (ap.resource_id = b.factura_id OR ap.resource_id IS NULL)
   AND ap.permiso = 'VIEW'
   AND ap.revoked_at IS NULL
   AND (ap.expires_at IS NULL OR ap.expires_at > NOW())
JOIN core.grupo_trabajo gt
    ON gt.grupo_id = ap.grantee_grupo_id
   AND gt.activo = TRUE
GROUP BY
    b.factura_id,
    b.cedente_org_id,
    b.cedente_razon_social,
    b.deudor_nombre,
    b.deudor_rut,
    b.factura_numero,
    b.monto_total,
    b.fecha_vencimiento,
    b.factura_status,
    b.created_at,
    b.updated_at,
    b.total_ofertas,
    b.ofertas_enviadas,
    b.ofertas_revisadas,
    b.ofertas_aceptadas,
    b.ofertas_rechazadas,
    b.mejor_tasa,
    b.mejor_monto_oferta,
    b.ultima_actualizacion_oferta,
    b.esta_ofertada,
    b.cedente_rut,
    b.url_path,
    b.gestor_uuid,
    b.username,
    b.correlation_id,
    b.adjuntos,
    gt.organizacion_id;

-- Consultas listas para usar:

-- Listado para un usuario (cualquier portal), sin fijar org:
-- check_access

-- Listado para un usuario dentro de una org específica (portal financiadora o cedente):
-- SELECT *
-- FROM permisos.obtener_facturas_accesibles(
-- 'UUID_USUARIO'::UUID,
-- 'UUID_ORGANIZACION'::UUID
-- );

-- Panel por organización financiera:
-- SELECT *
-- FROM permisos.vw_facturas_accesibles_por_org
-- WHERE financiera_org_id = 'UUID_ORGANIZACION_FINANCIADORA'::UUID
-- ORDER BY created_at DESC;Consultas listas para usar:

-- Listado para un usuario (cualquier portal), sin fijar org:
-- SELECT *
-- FROM permisos.obtener_facturas_accesibles(
-- 'UUID_USUARIO'::UUID,
-- NULL
-- );

-- Listado para un usuario dentro de una org específica (portal financiadora o cedente):
-- SELECT *
-- FROM permisos.obtener_facturas_accesibles(
-- 'UUID_USUARIO'::UUID,
-- 'UUID_ORGANIZACION'::UUID
-- );

-- Panel por organización financiera:
-- SELECT *
-- FROM permisos.vw_facturas_accesibles_por_org
-- WHERE financiera_org_id = 'UUID_ORGANIZACION_FINANCIADORA'::UUID
-- ORDER BY created_at DESC;

-- =========================================================
-- 13. GRANTS AL ROL DE DESARROLLO
-- =========================================================
GRANT ALL PRIVILEGES ON SCHEMA permisos TO desarrollo;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA permisos TO desarrollo;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA permisos TO desarrollo;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA permisos TO desarrollo;

-- =========================================================
-- NOTA DE COMPATIBILIDAD CON 08_media_permissions.sql
-- =========================================================
-- Las tablas core.media_asset_owner / core.media_access_policy /
-- core.media_cross_org_sharing / core.media_access_audit siguen
-- activas para el código existente.
--
-- Migración gradual sugerida:
--   1. El backend nuevas llamadas usan permisos.check_access('MEDIA_ASSET', ...).
--   2. En un sprint posterior, poblar permisos.resource_owner desde media_asset_owner
--      y deprecar las tablas core.media_*.
--
-- Para QUERY_FACTURA (permiso lógico sin resource_id fijo) usar resource_id = NULL
-- y p_organizacion_id para filtrar, ej:
--   SELECT permisos.check_access('QUERY_FACTURA', NULL, :uuid, 'VIEW', :org_id);
-- =========================================================

-- =========================================================
-- EJEMPLOS DE USO PRÁCTICO
-- =========================================================

-- 1. CASO: Otorgar acceso a una factura a TODOS los grupos de una organización FINANCIERA
--
--    Factura:           62ed9524-24d8-4b39-ac7f-cc7245c1fe40
--    Org emisora:       01cfc6e9-5d74-4271-8fe0-6d755d91f6e1
--    Org financiera:    <insert_financiera_org_uuid>
--    Granter (usuario): 3549d4fa-95ea-4867-a543-08ac38dda215
--
-- SELECT permisos.grant_access_to_organization_groups(
--     'FACTURA',
--     '62ed9524-24d8-4b39-ac7f-cc7245c1fe40'::UUID,
--     '<insert_financiera_org_uuid>'::UUID,
--     '3549d4fa-95ea-4867-a543-08ac38dda215'::UUID,
--     'VIEW',
--     'Factura compartida con financiadora'
-- );
-- Retorna: número de grupos en la org financiera que recibieron el permiso

-- 2. Verificar si un usuario (ejecutivo de financiera) puede ver la factura:
-- SELECT permisos.check_access(
--     'FACTURA',
--     '62ed9524-24d8-4b39-ac7f-cc7245c1fe40'::UUID,
--     '<usuario_ejecutivo_uuid>'::UUID,
--     'VIEW',
--     '<financiera_org_uuid>'::UUID
-- );
-- Retorna: TRUE si tiene acceso (directo, por grupo, o cross-org)

-- 3. Auditar quién vio qué:
-- SELECT * FROM permisos.access_audit
-- WHERE resource_type = 'FACTURA'
--   AND resource_id = '62ed9524-24d8-4b39-ac7f-cc7245c1fe40'::UUID
-- ORDER BY accessed_at DESC;

-- 4. Revocar acceso de un grupo a una factura:
-- SELECT permisos.revoke_access(
--     'FACTURA',
--     '62ed9524-24d8-4b39-ac7f-cc7245c1fe40'::UUID,
--     '<grupo_id>'::UUID,
--     'VIEW'
-- );
-- Nota: usar ON CONFLICT en access_policy si necesitas revocar grupos.

-- 5. Obtener facturas accesibles para un usuario ejecutivo:
-- SELECT * FROM permisos.obtener_facturas_accesibles(
--     '<usuario_ejecutivo_uuid>'::UUID,
--     '<financiera_org_uuid>'::UUID
-- )
-- WHERE tiene_permiso = TRUE;
-- Retorna: factura_id, folio, cliente, monto, gestor, fecha_vencimiento, tiene_permiso

-- 6. Ver facturas accesibles por grupo/org (vista):
-- SELECT * FROM permisos.vw_facturas_accesibles_por_org
-- WHERE financiera_org_id = '<financiera_org_uuid>'::UUID;

