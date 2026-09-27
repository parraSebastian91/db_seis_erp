-- =============================================================================
-- 19_dev_seed_org_miembros.sql  (SOLO DESARROLLO)
-- Deriva membresías de core.organizacion_miembro desde core.organizacion_contacto:
-- si el contacto de una organización tiene usuario, ese usuario es miembro
-- (ADMIN si es el contacto principal, COLABORADOR en otro caso). Sin esto los
-- usuarios de prueba no pertenecen a ninguna organización y el portal los deriva
-- al wizard /sin-organizacion.
-- Idempotente. No corre en producción.
-- =============================================================================
INSERT INTO core.organizacion_miembro (organizacion_id, usuario_uuid, rol_codigo, activo)
SELECT DISTINCT ON (oc.organizacion_id, u.usuario_uuid)
       oc.organizacion_id,
       u.usuario_uuid,
       CASE WHEN oc.es_principal THEN 'ADMIN' ELSE 'COLABORADOR' END,
       true
FROM core.organizacion_contacto oc
JOIN identity.usuario u ON u.contacto_id = oc.contacto_id
ORDER BY oc.organizacion_id, u.usuario_uuid, oc.es_principal DESC
ON CONFLICT (organizacion_id, usuario_uuid) DO NOTHING;
