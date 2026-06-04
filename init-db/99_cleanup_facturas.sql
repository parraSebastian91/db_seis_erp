-- =============================================================================
-- SCRIPT DE LIMPIEZA: factura.factura y tablas dependientes
-- ⚠️  USO EXCLUSIVO EN DESARROLLO / QA — NO EJECUTAR EN PRODUCCIÓN
--
-- Orden de borrado (respeta foreign keys):
--   1. factura.ofertas                    → FK → factura.factura (sin CASCADE)
--   2. factura.historial_negocios         → FK → factura.factura (sin CASCADE)
--   3. factura.autorizacion_publicacion   → FK → factura.factura (sin CASCADE)
--   4. factura.factura                    → tabla principal
--      └─ factura.notas_ocr              → ON DELETE CASCADE (se borra solo)
--
-- Datos huérfanos en permisos (UUID polimórfico, sin FK real):
--   5. permisos.resource_owner   WHERE resource_type = 'FACTURA'
--   6. permisos.access_policy    WHERE resource_type = 'FACTURA'
--   7. permisos.access_audit     WHERE resource_type = 'FACTURA'
-- =============================================================================

-- DDL fuera de transacción (requiere owner de tabla o superuser)
ALTER TABLE factura.autorizacion_publicacion DISABLE TRIGGER ALL;

BEGIN;

-- 1. Ofertas de financiamiento
DELETE FROM factura.ofertas;

-- 2. Historial de negocios
DELETE FROM factura.historial_negocios;

-- 3. Consentimientos de publicación (trigger deshabilitado arriba)
DELETE FROM factura.autorizacion_publicacion;

-- 4. Facturas (notas_ocr se elimina en cascada automáticamente)
DELETE FROM factura.factura;

-- 5-7. Limpiar registros huérfanos en el esquema de permisos
DELETE FROM permisos.resource_owner  WHERE resource_type = 'FACTURA';
DELETE FROM permisos.access_policy   WHERE resource_type = 'FACTURA';
DELETE FROM permisos.access_audit    WHERE resource_type = 'FACTURA';

COMMIT;

-- Rehabilitar el trigger una vez confirmada la transacción
ALTER TABLE factura.autorizacion_publicacion ENABLE TRIGGER ALL;
