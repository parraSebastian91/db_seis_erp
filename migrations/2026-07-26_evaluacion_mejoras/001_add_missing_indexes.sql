-- =============================================================================
-- 001_add_missing_indexes.sql
-- Agregar índices faltantes en Foreign Keys
-- Prioridad: 🔴 CRÍTICA
-- Estimación: 20 minutos
-- Riesgo: Bajo (índices son DDL no bloqueantes con CONCURRENTLY)
-- 
-- ⚠️ NOTA: Schema bodega está en stand-by y NO se incluye en esta migración.
-- =============================================================================

BEGIN;

-- ============================================================================
-- SCHEMA: core
-- ============================================================================

-- Usuario → Contacto (JOIN frecuente en autenticación)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_usuario_contacto_id 
ON core.usuario(contacto_id);

-- Grupo Miembro → Usuario (JOIN en verificación de permisos)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_grupo_miembro_usuario_uuid 
ON core.grupo_miembro(usuario_uuid);

-- Grupo Miembro → Grupo (JOIN en jerarquías)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_grupo_miembro_grupo_id 
ON core.grupo_miembro(grupo_id);

-- Avatar Attachments → Usuario (JOIN en perfil de usuario)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_avatar_attachments_usuario_id 
ON core.avatar_attachments(usuario_id);

-- Organizacion Attachments → Organizacion (JOIN en perfil de org)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_organizacion_attachments_org_id 
ON core.organizacion_attachments(organizacion_id);

\echo 'Índices de core creados.'

-- ============================================================================
-- SCHEMA: factura
-- ============================================================================

-- Factura → Organizacion (JOIN crítico en marketplace)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_factura_organizacion_id 
ON factura.factura(organizacion_id);

-- Factura → Gestor Usuario (JOIN en queries de facturas por gestor)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_factura_gestor_usuario_uuid 
ON factura.factura(gestor_usuario_uuid) 
WHERE gestor_usuario_uuid IS NOT NULL;

-- Ofertas → Factura (JOIN en queries de ofertas por factura)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofertas_factura_id 
ON factura.ofertas(factura_id);

-- Ofertas → Financiadora (JOIN en dashboard financiadora)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofertas_financiadora_id 
ON factura.ofertas(financiadora_id);

-- Ofertas → Investor (JOIN en queries de ofertas por ejecutiva)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofertas_investor_id 
ON factura.ofertas(investor_id) 
WHERE investor_id IS NOT NULL;

-- Historial Negocios → Factura (JOIN en reputación)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_historial_negocios_factura_id 
ON factura.historial_negocios(factura_id);

-- Historial Negocios → Organizacion (JOIN en historial por cliente)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_historial_negocios_org_id 
ON factura.historial_negocios(organizacion_id);

-- Historial Negocios → Financiadora (JOIN en historial por financiadora)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_historial_negocios_financiadora_id 
ON factura.historial_negocios(financiadora_id);

-- Historial Negocios → Usuario (JOIN en historial por ejecutiva)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_historial_negocios_usuario_id 
ON factura.historial_negocios(usuario_id);

-- Factura Adjuntos → Factura (JOIN en visor documental)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_factura_adjuntos_factura_id_cascade 
ON factura.factura_adjuntos(factura_id);

-- Factura Adjuntos → Asset (JOIN en resolución de URLs)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_factura_adjuntos_asset_id_cascade 
ON factura.factura_adjuntos(asset_id);

-- Notas OCR → Factura (JOIN en discrepancias OCR)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notas_ocr_factura_id 
ON factura.notas_ocr(factura_id);

-- Autorizacion Publicacion → Factura (JOIN en compliance)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_autorizacion_factura_id 
ON factura.autorizacion_publicacion(factura_id);

-- Autorizacion Publicacion → Usuario (JOIN en auditoría)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_autorizacion_usuario_uuid 
ON factura.autorizacion_publicacion(usuario_uuid);

-- Autorizacion Publicacion → Version Terminos (JOIN en histórico de versiones)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_autorizacion_version_terminos 
ON factura.autorizacion_publicacion(version_terminos_id);

\echo 'Índices de factura creados.'

-- ============================================================================
-- SCHEMA: media
-- ============================================================================

-- Media Variants → Asset (JOIN crítico en resolución de URLs)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_media_variants_asset_id 
ON media.media_variants(asset_id);

\echo 'Índices de media creados.'

-- ============================================================================
-- SCHEMA: permisos
-- ============================================================================

-- Resource Owner → Organizacion (JOIN en permisos organizacionales)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_perm_owner_org_cascade 
ON permisos.resource_owner(organizacion_id);

-- Access Policy → Organizacion (JOIN en permisos por org)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_perm_policy_org_cascade 
ON permisos.access_policy(organizacion_id);

-- Access Audit → Usuario (JOIN en auditoría por usuario)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_perm_audit_usuario_cascade 
ON permisos.access_audit(usuario_uuid);

-- Access Audit → Organizacion (JOIN en auditoría por org)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_perm_audit_org_cascade 
ON permisos.access_audit(organizacion_id);

\echo 'Índices de permisos creados.'

-- ============================================================================
-- SCHEMA: core (complementarios)
-- ============================================================================

-- Organizacion Perfil → Organizacion (JOIN en perfil extendido)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_org_perfil_organizacion_id 
ON core.organizacion_perfil(organizacion_id);

-- Organizacion Credencial SII → Organizacion (JOIN en credenciales tributarias)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_org_credencial_sii_org_id 
ON core.organizacion_credencial_sii(organizacion_id);

-- Email Verification Tokens → User (JOIN en verificación de correo)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_email_verification_user_id 
ON core.email_verification_tokens(user_id, expires_at);

\echo 'Índices complementarios de core creados.'

COMMIT;

\echo ''
\echo '========================================='
\echo 'Resumen de índices creados:'
\echo '========================================='

SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE indexname IN (
    'idx_usuario_contacto_id',
    'idx_org_dir_organizacion_id',SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE indexname IN (
    'idx_usuario_contacto_id',
    'idx_org_dir_organizacion_id',
    'idx_factura_organizacion_id',
    'idx_ofertas_factura_id',
    'idx_ofertas_financiadora_id',
    'idx_media_variants_asset_id',
    'idx_org_perfil_organizacion_id',
    'idx_email_verification_user_id'
)
ORDER BY schemaname, tablename;

    'idx_factura_organizacion_id',
    'idx_ofertas_factura_id',
    'idx_ofertas_financiadora_id',
    'idx_media_variants_asset_id',
    'idx_org_perfil_organizacion_id',
    'idx_email_verification_user_id'
)
ORDER BY schemaname, tablename;

\echo ''
\echo '========================================='
\echo 'Verificación de uso de índices:'
\echo '========================================='
\echo 'Ejecutar en producción después de 1 semana:'
\echo 'SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read'
\echo 'FROM pg_stat_user_indexes'
\echo 'WHERE indexname LIKE '\''idx_%'\'''
\echo 'ORDER BY idx_scan DESC LIMIT 20;'
\echo ''SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE indexname IN (
    'idx_usuario_contacto_id',
    'idx_org_dir_organizacion_id',
    'idx_factura_organizacion_id',
    'idx_ofertas_factura_id',
    'idx_ofertas_financiadora_id',
    'idx_media_variants_asset_id',
    'idx_org_perfil_organizacion_id',
    'idx_email_verification_user_id'
)
ORDER BY schemaname, tablename;


-- =============================================================================
-- ROLLBACK (en caso de error)
-- =============================================================================
/*
DROP INDEX IF EXISTS core.idx_usuario_contacto_id;
DROP INDEX IF EXISTS core.idx_org_dir_organizacion_id;
DROP INDEX IF EXISTS core.idx_grupo_miembro_usuario_uuid;
DROP INDEX IF EXISTS core.idx_grupo_miembro_grupo_id;
DROP INDEX IF EXISTS core.idx_avatar_attachments_usuario_id;
DROP INDEX IF EXISTS core.idx_organizacion_attachments_org_id;
DROP INDEX IF EXISTS core.idx_org_perfil_organizacion_id;
DROP INDEX IF EXISTS core.idx_org_credencial_sii_org_id;
DROP INDEX IF EXISTS core.idx_email_verification_user_id;
DROP INDEX IF EXISTS factura.idx_factura_organizacion_id;
DROP INDEX IF EXISTS factura.idx_factura_gestor_usuario_uuid;
DROP INDEX IF EXISTS factura.idx_ofertas_factura_id;
DROP INDEX IF EXISTS factura.idx_ofertas_financiadora_id;
DROP INDEX IF EXISTS factura.idx_ofertas_investor_id;
DROP INDEX IF EXISTS factura.idx_historial_negocios_factura_id;
DROP INDEX IF EXISTS factura.idx_historial_negocios_org_id;
DROP INDEX IF EXISTS factura.idx_historial_negocios_financiadora_id;
DROP INDEX IF EXISTS factura.idx_historial_negocios_usuario_id;
DROP INDEX IF EXISTS factura.idx_factura_adjuntos_factura_id_cascade;
DROP INDEX IF EXISTS factura.idx_factura_adjuntos_asset_id_cascade;
DROP INDEX IF EXISTS factura.idx_notas_ocr_factura_id;
DROP INDEX IF EXISTS factura.idx_autorizacion_factura_id;
DROP INDEX IF EXISTS factura.idx_autorizacion_usuario_uuid;
DROP INDEX IF EXISTS factura.idx_autorizacion_version_terminos;
DROP INDEX IF EXISTS media.idx_media_variants_asset_id;
DROP INDEX IF EXISTS permisos.idx_perm_owner_org_cascade;
DROP INDEX IF EXISTS permisos.idx_perm_policy_org_cascade;
DROP INDEX IF EXISTS permisos.idx_perm_audit_usuario_cascade;
DROP INDEX IF EXISTS permisos.idx_perm_audit_org_cascade;
*/
