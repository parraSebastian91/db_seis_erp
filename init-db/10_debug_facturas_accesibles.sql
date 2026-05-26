-- =============================================================================
-- DEBUG: Diagnóstico de por qué no aparecen facturas en obtener_facturas_accesibles
-- Ejecuta cada bloque por separado y observa los resultados.
-- Reemplaza :UUID_USUARIO y :UUID_ORG con valores reales antes de ejecutar.
-- =============================================================================

-- =============================================================================
-- PASO 0: Reemplaza estos valores antes de ejecutar
-- =============================================================================
-- \set usuario_uuid 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
-- \set org_uuid     'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'


-- =============================================================================
-- PASO 1: ¿Existen facturas en estado PUBLICADA u OFERTADA?
-- Causa: La vista base solo muestra estos dos estados.
-- Si retorna 0 → el problema es que las facturas no están publicadas.
-- =============================================================================
SELECT
    status::TEXT,
    COUNT(*) AS total
FROM factura.factura
GROUP BY status
ORDER BY status;


-- =============================================================================
-- PASO 2: ¿La vista base devuelve registros?
-- Si PASO 1 tiene PUBLICADA/OFERTADA pero aquí retorna 0 → problema en la vista.
-- =============================================================================
SELECT COUNT(*) AS total_en_vista_base
FROM permisos.vw_facturas_publicadas_ofertadas_base;


-- =============================================================================
-- PASO 3: ¿El usuario existe y pertenece a algún grupo activo?
-- Si retorna 0 → el usuario no tiene grupos → check_access fallará para permisos por grupo.
-- Reemplaza :UUID_USUARIO con el UUID real.
-- =============================================================================
SELECT
    u.usuario_uuid,
    u.userName,
    gt.grupo_id,
    gt.nombre AS nombre_grupo,
    o.razon_social AS org_grupo,
    o.tipo_participante
FROM core.usuario u
LEFT JOIN core.grupo_miembro gm ON gm.usuario_uuid = u.usuario_uuid AND gm.active = TRUE
LEFT JOIN core.grupo_trabajo gt ON gt.grupo_id = gm.grupo_id AND gt.activo = TRUE
LEFT JOIN core.organizacion o ON o.organizacion_uuid = gt.organizacion_id
WHERE u.usuario_uuid = :'usuario_uuid';  -- Reemplaza con UUID real


-- =============================================================================
-- PASO 4: ¿Hay facturas con propietario registrado en resource_owner?
-- Si retorna 0 → Las facturas fueron creadas ANTES del trigger → ejecutar backfill (PASO 8).
-- =============================================================================
SELECT COUNT(*) AS total_con_owner_registrado
FROM permisos.resource_owner
WHERE resource_type = 'FACTURA';


-- =============================================================================
-- PASO 5: ¿El usuario específico es propietario de alguna factura?
-- Si retorna 0 pero tiene facturas → es el backfill faltante.
-- =============================================================================
SELECT
    ro.resource_id AS factura_id,
    ro.es_propietario_principal,
    f.factura_numero,
    f.status::TEXT
FROM permisos.resource_owner ro
JOIN factura.factura f ON f.id = ro.resource_id
WHERE ro.resource_type = 'FACTURA'
  AND ro.owner_usuario_uuid = :'usuario_uuid';  -- Reemplaza con UUID real


-- =============================================================================
-- PASO 6: ¿Hay access_policy activa para FACTURA para los grupos del usuario?
-- Si retorna 0 → no se ejecutó grant_access_to_organization_groups al publicar.
-- =============================================================================
SELECT
    ap.resource_id AS factura_id,
    ap.grantee_grupo_id,
    ap.grantee_usuario_uuid,
    ap.permiso,
    ap.organizacion_id,
    ap.revoked_at,
    ap.expires_at
FROM permisos.access_policy ap
JOIN core.grupo_miembro gm
    ON gm.grupo_id = ap.grantee_grupo_id
   AND gm.usuario_uuid = :'usuario_uuid'  -- Reemplaza con UUID real
   AND gm.active = TRUE
WHERE ap.resource_type = 'FACTURA'
  AND ap.revoked_at IS NULL
  AND (ap.expires_at IS NULL OR ap.expires_at > NOW())
LIMIT 20;


-- =============================================================================
-- PASO 7: Simular check_access para una factura puntual
-- Reemplaza los UUIDs con valores reales.
-- Debe retornar TRUE si todo está bien.
-- =============================================================================
SELECT
    f.id AS factura_id,
    f.factura_numero,
    f.status::TEXT,
    permisos.check_access(
        'FACTURA',
        f.id,
        :'usuario_uuid'::UUID,   -- Reemplaza con UUID real
        'VIEW',
        :'org_uuid'::UUID        -- Reemplaza con UUID real, o NULL para no restringir
    ) AS tiene_acceso
FROM factura.factura f
WHERE f.status IN ('PUBLICADA', 'OFERTADA')
LIMIT 10;


-- =============================================================================
-- PASO 8: BACKFILL — Registrar propietarios para facturas existentes
-- Ejecutar para facturas creadas ANTES del trigger.
-- Registra: gestor (principal) + su jefe directo por grupo (co-propietario).
-- Es seguro ejecutar múltiples veces (ON CONFLICT DO NOTHING).
-- =============================================================================

-- 8.A: Registrar al gestor como propietario principal
INSERT INTO permisos.resource_owner (
    resource_type,
    resource_id,
    owner_usuario_uuid,
    organizacion_id,
    es_propietario_principal
)
SELECT
    'FACTURA',
    f.id,
    f.gestor_usuario_uuid,
    f.organizacion_id,
    TRUE
FROM factura.factura f
WHERE f.gestor_usuario_uuid IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM permisos.resource_owner ro
      WHERE ro.resource_type = 'FACTURA'
        AND ro.resource_id = f.id
        AND ro.owner_usuario_uuid = f.gestor_usuario_uuid
  );

-- 8.B: Registrar al jefe directo del gestor como co-propietario
INSERT INTO permisos.resource_owner (
    resource_type,
    resource_id,
    owner_usuario_uuid,
    organizacion_id,
    es_propietario_principal
)
SELECT DISTINCT ON (f.id, jm_jefe.usuario_uuid)
    'FACTURA',
    f.id,
    jm_jefe.usuario_uuid,
    gt.organizacion_id,
    FALSE
FROM factura.factura f
JOIN core.grupo_miembro gm_gestor
    ON gm_gestor.usuario_uuid = f.gestor_usuario_uuid
   AND gm_gestor.active = TRUE
   AND gm_gestor.jefe_directo_id IS NOT NULL
JOIN core.grupo_miembro jm_jefe
    ON jm_jefe.miembro_id = gm_gestor.jefe_directo_id
   AND jm_jefe.active = TRUE
   AND jm_jefe.usuario_uuid <> f.gestor_usuario_uuid
JOIN core.grupo_trabajo gt
    ON gt.grupo_id = gm_gestor.grupo_id
   AND gt.activo = TRUE
WHERE f.gestor_usuario_uuid IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM permisos.resource_owner ro
      WHERE ro.resource_type = 'FACTURA'
        AND ro.resource_id = f.id
        AND ro.owner_usuario_uuid = jm_jefe.usuario_uuid
  );

-- Verificar cuántas filas hay ahora:
SELECT
    es_propietario_principal,
    COUNT(*) AS total
FROM permisos.resource_owner
WHERE resource_type = 'FACTURA'
GROUP BY es_propietario_principal;


-- =============================================================================
-- PASO 9: VERIFICACIÓN FINAL — Llamar la función con usuario y org reales
-- Si llegaste aquí y todo lo anterior está OK, esto debe retornar filas.
-- =============================================================================
SELECT
    factura_id,
    factura_numero,
    cedente_razon_social,
    deudor_nombre,
    monto_total,
    factura_status,
    tiene_permiso,
    org_contexto_uuid
FROM permisos.obtener_facturas_accesibles(
    :'usuario_uuid'::UUID,   -- Reemplaza con UUID real
    NULL                     -- NULL = todas las orgs del usuario, o pasar UUID de org específica
)
ORDER BY created_at DESC;
