-- =============================================================================
-- 003_remove_duplicate_indexes.sql
-- Eliminar índices duplicados y obsoletos
-- Prioridad: 🔴 CRÍTICA
-- Estimación: 5 minutos
-- Riesgo: Bajo (DROP INDEX no bloqueante con CONCURRENTLY)
-- =============================================================================

\echo '========================================='
\echo 'Eliminando índices duplicados...'
\echo '========================================='

BEGIN;

-- ============================================================================
-- SCHEMA: core
-- ============================================================================

\echo ''
\echo 'Analizando índices de core.auth_refresh_sessions...'

-- Listar índices actuales
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE schemaname = 'core' 
  AND tablename = 'auth_refresh_sessions'
ORDER BY indexname;

\echo ''
\echo 'Eliminando índices duplicados en auth_refresh_sessions...'

-- Estos índices están duplicados (líneas 314-318 de 01_init_core.sql)
-- Se mantienen las versiones con schema explícito (líneas 320-333)

DROP INDEX CONCURRENTLY IF EXISTS idx_auth_refresh_sessions_user_id;
\echo '  ✅ Eliminado: idx_auth_refresh_sessions_user_id (duplicado de core.idx_auth_refresh_sessions_user_id)'

DROP INDEX CONCURRENTLY IF EXISTS idx_auth_refresh_sessions_expires_at;
\echo '  ✅ Eliminado: idx_auth_refresh_sessions_expires_at (duplicado de core.idx_auth_refresh_sessions_expires_at)'

DROP INDEX CONCURRENTLY IF EXISTS idx_auth_refresh_sessions_device_user;
\echo '  ✅ Eliminado: idx_auth_refresh_sessions_device_user (duplicado de core.idx_auth_refresh_sessions_device_user)'

DROP INDEX CONCURRENTLY IF EXISTS idx_auth_refresh_sessions_rotation_parent;
\echo '  ✅ Eliminado: idx_auth_refresh_sessions_rotation_parent (duplicado de core.idx_auth_refresh_sessions_rotation_parent)'

DROP INDEX CONCURRENTLY IF EXISTS idx_auth_refresh_sessions_token_hash;
\echo '  ✅ Eliminado: idx_auth_refresh_sessions_token_hash (duplicado de core.idx_auth_refresh_sessions_token_hash)'

-- ============================================================================
-- Verificar índices que quedaron activos
-- ============================================================================

\echo ''
\echo 'Índices activos en auth_refresh_sessions (post-limpieza):'
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE schemaname = 'core' 
  AND tablename = 'auth_refresh_sessions'
ORDER BY indexname;

COMMIT;

\echo ''
\echo '========================================='
\echo 'Análisis de uso de índices (opcional)'
\echo '========================================='
\echo ''
\echo 'Para verificar que los índices restantes se usan correctamente,'
\echo 'ejecutar después de 1 semana en producción:'
\echo ''
\echo 'SELECT'
\echo '    schemaname,'
\echo '    tablename,'
\echo '    indexname,'
\echo '    idx_scan AS num_scans,'
\echo '    idx_tup_read AS tuples_read,'
\echo '    idx_tup_fetch AS tuples_fetched'
\echo 'FROM pg_stat_user_indexes'
\echo 'WHERE schemaname = '\''core'\'''
\echo '  AND tablename = '\''auth_refresh_sessions'\'''
\echo 'ORDER BY idx_scan DESC;'
\echo ''

-- ============================================================================
-- Verificación de espacio liberado
-- ============================================================================

\echo ''
\echo '========================================='
\echo 'Espacio liberado:'
\echo '========================================='

SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS indexes_size,
    (SELECT COUNT(*) 
     FROM pg_indexes 
     WHERE schemaname = 'core' 
       AND tablename = 'auth_refresh_sessions') AS num_indexes
FROM pg_tables
WHERE schemaname = 'core'
  AND tablename = 'auth_refresh_sessions';

\echo ''
\echo '========================================='
\echo '✅ LIMPIEZA COMPLETADA'
\echo '========================================='
\echo ''
\echo 'Resumen:'
\echo '  - Índices eliminados: 5 (duplicados en auth_refresh_sessions)'
\echo '  - Espacio liberado: variable (depende del tamaño de la tabla)'
\echo ''
\echo 'IMPORTANTE:'
\echo '  - Los índices con schema explícito (core.idx_*) se mantienen activos'
\echo '  - No se afecta el rendimiento de queries de autenticación'
\echo '  - Monitorear pg_stat_user_indexes después de 1 semana'
\echo ''

-- =============================================================================
-- ROLLBACK (en caso de error)
-- =============================================================================
/*
-- Recrear índices eliminados (solo si se necesita rollback)
CREATE INDEX CONCURRENTLY idx_auth_refresh_sessions_user_id 
    ON core.auth_refresh_sessions(user_id);
CREATE INDEX CONCURRENTLY idx_auth_refresh_sessions_expires_at 
    ON core.auth_refresh_sessions(expires_at);
CREATE INDEX CONCURRENTLY idx_auth_refresh_sessions_device_user 
    ON core.auth_refresh_sessions(device_fingerprint, user_id);
CREATE INDEX CONCURRENTLY idx_auth_refresh_sessions_rotation_parent 
    ON core.auth_refresh_sessions(rotation_parent_id);
CREATE INDEX CONCURRENTLY idx_auth_refresh_sessions_token_hash 
    ON core.auth_refresh_sessions(token_hash);
*/
