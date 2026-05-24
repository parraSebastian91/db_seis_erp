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
-- 11. FUNCIÓN: grant_user_whitelist_access
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
-- 12. VISTAS PRÁCTICAS PARA REPORTING Y ACCESO A DATOS
-- =========================================================


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

