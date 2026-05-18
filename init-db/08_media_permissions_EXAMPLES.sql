-- =============================================================================
-- EJEMPLOS DE USO: Cadena de Permisos de Media
-- =============================================================================

-- ============================================================================
-- 1. SETUP INICIAL: Registrar que un usuario es propietario de un media_asset
-- (Ejecutar después de subir un archivo)
-- ============================================================================

INSERT INTO core.media_asset_owner (
    media_id,
    owner_usuario_uuid,
    organizacion_id,
    es_propietario_principal
) VALUES (
    'f47ac10b-58cc-4372-a567-0e02b2c3d479'::UUID,  -- UUID del archivo subido
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::UUID,  -- UUID del usuario que subió
    1,                                              -- ID de la organización
    true
);

-- ============================================================================
-- 2. DAR ACCESO INDIVIDUAL: Usuario A puede ver archivos de Usuario B
-- (Dentro de la misma organización)
-- ============================================================================

INSERT INTO core.media_access_policy (
    media_id,
    grantee_usuario_uuid,                          -- Quién recibe acceso
    granter_usuario_uuid,                          -- Quién otorga (propietario)
    organizacion_id,
    permiso,
    razon_acceso,
    expires_at
) VALUES (
    'f47ac10b-58cc-4372-a567-0e02b2c3d479'::UUID,
    'b2c3d4e5-f6a7-8901-bcde-f12345678901'::UUID,  -- Ejecutivo que necesita ver
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::UUID,  -- Propietario del archivo
    1,
    'VIEW',                                         -- Can view metadata
    'Factura requiere revisión de ejecutivo',
    NOW() + INTERVAL '30 days'                      -- Válido por 30 días
);

-- ============================================================================
-- 3. DAR ACCESO A GRUPO: Todos los ejecutivos de un grupo ven los archivos
-- ============================================================================

INSERT INTO core.media_access_policy (
    media_id,
    grantee_grupo_id,                              -- Grupo que recibe acceso
    granter_usuario_uuid,
    organizacion_id,
    permiso,
    razon_acceso
) VALUES (
    'f47ac10b-58cc-4372-a567-0e02b2c3d479'::UUID,
    'group-uuid-123'::UUID,                         -- Grupo "Ejecutivos de Facturación"
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::UUID,
    1,
    'VIEW',
    'Acceso permanente para equipo de cobranza'
);

-- ============================================================================
-- 4. COMPARTIR ENTRE ORGANIZACIONES
-- Organización CEDENTE (que tiene las facturas) comparte con FINANCIADORA
-- ============================================================================

INSERT INTO core.media_cross_org_sharing (
    media_id,
    owner_organizacion_id,                         -- Org que tiene las facturas
    recipient_organizacion_id,                     -- Org financiadora
    granted_by_usuario_uuid,                       -- Admin de org cedente
    access_level,
    valid_until,
    razon_compartir
) VALUES (
    'f47ac10b-58cc-4372-a567-0e02b2c3d479'::UUID,
    1,                                              -- Cedente (propietaria)
    5,                                              -- Financiadora (receptora)
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::UUID,
    'VIEW',                                         -- Solo ver, no descargar
    NOW() + INTERVAL '90 days',
    'Compartir para análisis de facturas'
);

-- ============================================================================
-- 5. VERIFICAR ACCESO: ¿Puede el usuario ver este media_asset?
-- ============================================================================

-- En SQL:
SELECT core.check_media_access(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479'::UUID,  -- media_id
    'b2c3d4e5-f6a7-8901-bcde-f12345678901'::UUID,  -- usuario_uuid
    'VIEW'                                          -- permiso a verificar
) AS tiene_acceso;

-- En Go (en tu controller):
-- permiso := c.storageApplication.CheckMediaAccess(ctx.Context(), mediaID, usuarioUUID, "VIEW")
-- if !permiso {
--     return ctx.Status(fiber.StatusForbidden).JSON(...)
-- }

-- ============================================================================
-- 6. REGISTRAR ACCESO EN AUDITORÍA
-- ============================================================================

SELECT core.log_media_access(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479'::UUID,
    'b2c3d4e5-f6a7-8901-bcde-f12345678901'::UUID,
    1,                                              -- org_id
    'DOWNLOAD',                                     -- acción
    '192.168.1.100',                                -- IP
    'Mozilla/5.0...',                               -- User-Agent
    'correlation-id-xyz'                            -- Correlation ID
);

-- ============================================================================
-- 7. REVOCAR ACCESO
-- ============================================================================

UPDATE core.media_access_policy
SET revoked_at = NOW()
WHERE media_id = 'f47ac10b-58cc-4372-a567-0e02b2c3d479'::UUID
  AND grantee_usuario_uuid = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'::UUID
  AND revoked_at IS NULL;

-- ============================================================================
-- 8. LISTAR TODOS LOS MEDIA_ASSETS ACCESIBLES PARA UN USUARIO
-- ============================================================================

SELECT DISTINCT
    ma.id,
    ma.original_name,
    ma.category,
    ma.status,
    ma.created_at,
    mao.owner_usuario_uuid,
    'OWNER' AS access_type
FROM media.media_assets ma
JOIN core.media_asset_owner mao ON mao.media_id = ma.id
WHERE mao.owner_usuario_uuid = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'::UUID

UNION

SELECT DISTINCT
    ma.id,
    ma.original_name,
    ma.category,
    ma.status,
    ma.created_at,
    mao.owner_usuario_uuid,
    'INDIVIDUAL_GRANT' AS access_type
FROM media.media_assets ma
JOIN core.media_asset_owner mao ON mao.media_id = ma.id
JOIN core.media_access_policy map ON map.media_id = ma.id
WHERE map.grantee_usuario_uuid = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'::UUID
  AND map.revoked_at IS NULL
  AND (map.expires_at IS NULL OR map.expires_at > NOW())

UNION

SELECT DISTINCT
    ma.id,
    ma.original_name,
    ma.category,
    ma.status,
    ma.created_at,
    mao.owner_usuario_uuid,
    'GROUP_GRANT' AS access_type
FROM media.media_assets ma
JOIN core.media_asset_owner mao ON mao.media_id = ma.id
JOIN core.media_access_policy map ON map.media_id = ma.id
JOIN core.grupo_miembro gm ON gm.grupo_id = map.grantee_grupo_id
WHERE gm.usuario_uuid = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'::UUID
  AND map.revoked_at IS NULL
  AND (map.expires_at IS NULL OR map.expires_at > NOW())
  AND gm.active = true

ORDER BY created_at DESC;

-- ============================================================================
-- 9. AUDITORÍA: Ver quién accedió a qué
-- ============================================================================

SELECT
    maa.accion,
    u.username,
    o.razon_social,
    maa.accessed_at,
    maa.ip_address,
    maa.correlation_id
FROM core.media_access_audit maa
JOIN core.usuario u ON u.usuario_uuid = maa.usuario_uuid
JOIN core.organizacion o ON o.organizacion_id = maa.organizacion_id
WHERE maa.media_id = 'f47ac10b-58cc-4372-a567-0e02b2c3d479'::UUID
ORDER BY maa.accessed_at DESC;
