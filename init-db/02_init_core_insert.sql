-- =============================================================================
-- Datos de Prueba - ERP Core (adaptado a 01_init_core.sql actual)
-- =============================================================================

SET search_path TO core, public;

-- (Opcional para re-ejecución limpia)
-- TRUNCATE TABLE
--   core.auth_refresh_sessions,
--   core.usuario_rol,
--   core.rol_modulo_permiso,
--   core.permiso,
--   core.rol,
--   core.funcionalidad,
--   core.modulo,
--   core.organizacion_sistema,
--   core.sistema,
--   core.grupo_miembro,
--   core.grupo_trabajo,
--   core.cuenta_bancaria,
--   core.organizacion_contacto,
--   core.usuario,
--   core.organizacion,
--   core.contacto,
--   core.tipo_contacto
-- RESTART IDENTITY CASCADE;

-- ============================================
-- 1) TIPOS DE CONTACTO
-- ============================================
INSERT INTO core.tipo_contacto (tipo_contacto_id, nombre, descripcion) VALUES
(1, 'Personal', 'Contacto de persona natural'),
(2, 'Empresa', 'Contacto empresarial'),
(3, 'Proveedor', 'Contacto de proveedor'),
(4, 'Cliente', 'Contacto de cliente'),
(5, 'Empleado', 'Contacto de empleado')
ON CONFLICT (tipo_contacto_id) DO NOTHING;

-- ============================================
-- 2) CONTACTOS (nueva estructura: nombres/apellidos, sin url)
-- ============================================
INSERT INTO core.contacto (
  contacto_id, nombres, apellido_paterno, apellido_materno,
  direccion, celular, correo, redes_sociales, tipo_contacto_id
) VALUES
(1, 'Juan',   'Pérez',     NULL, 'Av. Libertador 1234, Santiago', '+56912345678', 'juan.perez@email.com', '{"twitter":"@juanp","linkedin":"juanperez"}', 2),
(2, 'María',  'González',  NULL, 'Calle Principal 567, Valparaíso', '+56987654321', 'maria.gonzalez@email.com', '{"instagram":"@mariag"}', 2),
(3, 'TechSupply SpA', NULL, NULL, 'Av. Apoquindo 3000, Las Condes', '+56223456789', 'contacto@techsupply.cl', '{"linkedin":"techsupply"}', 3),
(4, 'Distribuidora Los Andes', NULL, NULL, 'Los Carrera 890, Maipú', '+56224567890', 'ventas@losandes.cl', '{}'::jsonb, 3),
(5, 'Comercial Pacific', NULL, NULL, 'Av. Pedro de Valdivia 1500, Providencia', '+56225678901', 'info@pacific.cl', '{"facebook":"pacificchile"}', 4),
(6, 'Ana',    'Martínez',  NULL, 'Las Condes 234, Santiago', '+56998765432', 'ana.martinez@email.com', '{}'::jsonb, 5),
(7, 'Carlos', 'Rojas',     NULL, 'Ñuñoa 456, Santiago', '+56976543210', 'carlos.rojas@email.com', '{"linkedin":"carlosrojas"}', 5),
(8, 'Softech Consulting', NULL, NULL, 'Vitacura 2800, Santiago', '+56226789012', 'contact@softech.cl', '{"linkedin":"softech","twitter":"@softech"}', 1),
(9, 'Constructora Norte', NULL, NULL, 'Huérfanos 1234, Santiago Centro', '+56227890123', 'contacto@norte.cl', '{}'::jsonb, 4),
(10,'Pedro',  'Silva',     NULL, 'San Miguel 789, Santiago', '+56965432109', 'pedro.silva@email.com', '{}'::jsonb, 2)
ON CONFLICT (contacto_id) DO NOTHING;

-- ============================================
-- 3) ORGANIZACIONES (sin contacto_id en esta tabla)
-- ============================================
INSERT INTO core.organizacion (
  organizacion_id, razon_social, tipo_organizacion, rut, dv, giro, activo
) VALUES
(1, 'Empresa Demo S.A.', 'JURIDICA', '76123456', '7', 'Servicios de Tecnología', true),
(2, 'Comercial Sur Limitada', 'JURIDICA', '77234567', '8', 'Comercio al por Mayor', true),
(3, 'Industrias del Pacífico S.A.', 'JURIDICA', '78345678', '9', 'Manufactura Industrial', true),
(4, 'Servicios Profesionales SpA', 'JURIDICA', '79456789', '0', 'Consultoría y Asesorías', true),
(5, 'Distribuidora Central', 'JURIDICA', '80567890', 'K', 'Distribución y Logística', false)
ON CONFLICT (organizacion_id) DO NOTHING;

-- ============================================
-- 4) ORGANIZACION_CONTACTO (N:N + principal único por organización)
-- ============================================
INSERT INTO core.organizacion_contacto (organizacion_id, contacto_id, cargo, es_principal) VALUES
(1, 8,  'Proveedor tecnológico', true),
(1, 1,  'Representante', false),
(1, 6,  'RRHH', false),
(1, 7,  'Operaciones', false),
(2, 5,  'Contacto comercial', true),
(2, 9,  'Cliente asociado', false),
(3, 3,  'Proveedor', true),
(3, 4,  'Distribución', false),
(4, 1,  'Consultor', true),
(4, 10, 'Ejecutivo', false),
(5, 4,  'Proveedor principal', true),
(5, 2,  'Contacto administrativo', false)
ON CONFLICT (organizacion_id, contacto_id) DO NOTHING;

-- ============================================
-- 5) CUENTAS BANCARIAS
-- ============================================
INSERT INTO core.cuenta_bancaria (organizacion_id, nombre_titular, rut_titular, banco, numero, correo_contacto) VALUES
(1, 'Empresa Demo S.A.', '76123456-7', 'Banco de Chile', '12345678901', 'finanzas@empresademo.cl'),
(1, 'Empresa Demo S.A.', '76123456-7', 'Banco Estado', '98765432109', 'tesoreria@empresademo.cl'),
(2, 'Comercial Sur Limitada', '77234567-8', 'Banco Santander', '11223344556', 'pagos@comercialsur.cl'),
(3, 'Industrias del Pacífico S.A.', '78345678-9', 'Banco BCI', '55667788990', 'contabilidad@industriaspacifico.cl'),
(4, 'Servicios Profesionales SpA', '79456789-0', 'Banco Itaú', '99887766554', 'admin@serviciospro.cl'),
(5, 'Distribuidora Central', '80567890-K', 'Banco Scotiabank', '44556677889', 'cuentas@distribuidoracentral.cl');

-- ============================================
-- 6) SISTEMAS / MÓDULOS / FUNCIONALIDADES
-- ============================================
INSERT INTO core.sistema (sistema_id, nombre, path, descripcion, activo) VALUES
(1, 'ERP Core', '/erp', 'Sistema central ERP', true),
(2, 'CRM', '/crm', 'Gestión de clientes', true),
(3, 'HRM', '/hrm', 'Recursos humanos', true),
(4, 'Finanzas', '/finance', 'Gestión financiera', true),
(5, 'Inventario', '/inventory', 'Gestión de inventarios', true)
ON CONFLICT (sistema_id) DO NOTHING;

INSERT INTO core.modulo (modulo_id, nombre, path, descripcion, activo, sistema_id) VALUES
(1, 'Administración', '/admin', 'Usuarios y configuración', true, 1),
(2, 'Organizaciones', '/organizations', 'Empresas y contactos', true, 1),
(3, 'Seguridad', '/security', 'Acceso y permisos', true, 1),
(4, 'Clientes', '/customers', 'CRM clientes', true, 2),
(5, 'Ventas', '/sales', 'CRM ventas', true, 2),
(10, 'Contabilidad', '/accounting', 'Libro diario y mayor', true, 4),
(11, 'Tesorería', '/treasury', 'Caja y pagos', true, 4),
(12, 'Facturación', '/billing', 'DTE', true, 4),
(13, 'Almacenes', '/warehouses', 'Bodegas', true, 5),
(14, 'Productos', '/products', 'Catálogo', true, 5),
(15, 'Compras', '/purchases', 'Órdenes de compra', true, 5)
ON CONFLICT (modulo_id) DO NOTHING;

INSERT INTO core.funcionalidad (funcionalidad_id, nombre, descripcion, path, modulo_id, activo) VALUES
(1, 'Gestión de Usuarios', 'ABM usuarios', '/admin/users', 1, true),
(2, 'Gestión de Empresas', 'ABM organizaciones', '/organizations/companies', 2, true),
(3, 'Roles y Permisos', 'Configuración RBAC', '/security/roles', 3, true),
(4, 'Ficha de Cliente', 'Perfil cliente', '/customers/profile', 4, true),
(5, 'Pipeline de Ventas', 'Embudo comercial', '/sales/pipeline', 5, true),
(6, 'Libro Diario', 'Asientos contables', '/accounting/journal', 10, true),
(7, 'Flujo de Caja', 'Proyección de caja', '/treasury/cashflow', 11, true),
(8, 'Factura Electrónica', 'Emisión DTE', '/billing/invoice', 12, true),
(9, 'Stock por Bodega', 'Existencias', '/warehouses/stock', 13, true)
ON CONFLICT (funcionalidad_id) DO NOTHING;

INSERT INTO core.organizacion_sistema (organizacion_id, sistema_id) VALUES
(1,1),(1,2),(1,3),(1,4),
(2,1),(2,2),(2,5),
(3,1),(3,4),(3,5),
(4,1),(4,2),
(5,1),(5,5)
ON CONFLICT (organizacion_id, sistema_id) DO NOTHING;

-- ============================================
-- 7) RBAC (estructura actual: rol(nombre,codigo) y permiso(per_nombre,per_cod))
-- ============================================
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod) VALUES
(1,'Ver Usuarios','USR_VIEW'),
(2,'Crear Usuarios','USR_CREATE'),
(3,'Editar Usuarios','USR_EDIT'),
(4,'Eliminar Usuarios','USR_DELETE'),
(5,'Ver Contactos','CNT_VIEW'),
(6,'Crear Contactos','CNT_CREATE'),
(7,'Editar Contactos','CNT_EDIT'),
(8,'Eliminar Contactos','CNT_DELETE'),
(9,'Ver Organizaciones','ORG_VIEW'),
(10,'Administrar Sistema','SYS_ADMIN'),
(11,'Ver Bodegas','BDG_VIEW'),
(12,'Crear Bodegas','BDG_CREATE'),
(13,'Editar Bodegas','BDG_EDIT'),
(14,'Eliminar Bodegas','BDG_DELETE'),
(15,'Crear Item','ITM_CREATE'),
(16,'Ver Item','ITM_VIEW'),
(17,'Editar Item','ITM_EDIT'),
(18,'Eliminar Item','ITM_DELETE'),
(19,'Leer Menu','MENU_VIEW')
ON CONFLICT (permiso_id) DO NOTHING;

INSERT INTO core.rol (rol_id, nombre, codigo) VALUES
(1, 'Super Administrador', 'SUPER_ADMIN'),
(2, 'Administrador', 'ADMIN'),
(3, 'Usuario Estándar', 'USR_STD'),
(4, 'Supervisor', 'SUPERVISOR'),
(5, 'Solo Lectura', 'READ_ONLY')
ON CONFLICT (rol_id) DO NOTHING;

-- Super Administrador: acceso total
INSERT INTO core.rol_modulo_permiso (rol_id, modulo_id, permiso_id)
SELECT 1, m.modulo_id, p.permiso_id
FROM core.modulo m
CROSS JOIN core.permiso p
ON CONFLICT (rol_id, modulo_id, permiso_id) DO NOTHING;

-- Roles base mínimos
INSERT INTO core.rol_modulo_permiso (rol_id, modulo_id, permiso_id) VALUES
(2, 2, 9), (2, 2, 5), (2, 2, 6), (2, 2, 7),
(3, 4, 5), (3, 5, 5),
(4, 5, 5), (4, 5, 6), (4, 5, 7),
(5,10, 5), (5,11, 5), (5,12, 5)
ON CONFLICT (rol_id, modulo_id, permiso_id) DO NOTHING;

-- ============================================
-- 8) USUARIOS (contacto_id es UNIQUE y NOT NULL)
-- ============================================
INSERT INTO core.usuario (usuario_id, username, password_hash, activo, contacto_id) VALUES
(1, 'sparra',    '$2a$12$loT1eJ6.iwUCFg2/ajCu9O944h4j5LyiEYMrAwkCGcYoJinn2wC7W', true, 1),
(2, 'mgonzalez', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', true, 2),
(3, 'techsupply','$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', true, 3),
(4, 'losandes',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', true, 4),
(5, 'cpacific',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', true, 5),
(6, 'amartinez', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', true, 6),
(7, 'crojas',    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', true, 7),
(8, 'softech',   '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', true, 8),
(9, 'cnorte',    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', true, 9),
(10,'psilva',    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', true,10)
ON CONFLICT (usuario_id) DO NOTHING;

INSERT INTO core.usuario_rol (usuario_id, rol_id) VALUES
(1,1),(2,2),(3,3),(4,3),(5,4),(6,4),(7,3),(8,2),(9,5),(10,5)
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- ============================================
-- 9) SESIONES REFRESH (estructura actual)
-- ============================================


-- ============================================
-- 10) AJUSTE DE SECUENCIAS (por inserts con ID explícito)
-- ============================================
SELECT setval(pg_get_serial_sequence('core.tipo_contacto','tipo_contacto_id'), COALESCE((SELECT MAX(tipo_contacto_id) FROM core.tipo_contacto),1), true);
SELECT setval(pg_get_serial_sequence('core.contacto','contacto_id'), COALESCE((SELECT MAX(contacto_id) FROM core.contacto),1), true);
SELECT setval(pg_get_serial_sequence('core.organizacion','organizacion_id'), COALESCE((SELECT MAX(organizacion_id) FROM core.organizacion),1), true);
SELECT setval(pg_get_serial_sequence('core.sistema','sistema_id'), COALESCE((SELECT MAX(sistema_id) FROM core.sistema),1), true);
SELECT setval(pg_get_serial_sequence('core.modulo','modulo_id'), COALESCE((SELECT MAX(modulo_id) FROM core.modulo),1), true);
SELECT setval(pg_get_serial_sequence('core.funcionalidad','funcionalidad_id'), COALESCE((SELECT MAX(funcionalidad_id) FROM core.funcionalidad),1), true);
SELECT setval(pg_get_serial_sequence('core.permiso','permiso_id'), COALESCE((SELECT MAX(permiso_id) FROM core.permiso),1), true);
SELECT setval(pg_get_serial_sequence('core.rol','rol_id'), COALESCE((SELECT MAX(rol_id) FROM core.rol),1), true);
SELECT setval(pg_get_serial_sequence('core.usuario','usuario_id'), COALESCE((SELECT MAX(usuario_id) FROM core.usuario),1), true);

-- ============================================
-- 11) VALIDACIONES (existencia + integridad FK básica)
-- ============================================

-- Resumen de cargas
SELECT 'tipo_contacto' tabla, COUNT(*) registros FROM core.tipo_contacto
UNION ALL SELECT 'contacto', COUNT(*) FROM core.contacto
UNION ALL SELECT 'organizacion', COUNT(*) FROM core.organizacion
UNION ALL SELECT 'organizacion_contacto', COUNT(*) FROM core.organizacion_contacto
UNION ALL SELECT 'usuario', COUNT(*) FROM core.usuario
UNION ALL SELECT 'rol', COUNT(*) FROM core.rol
UNION ALL SELECT 'permiso', COUNT(*) FROM core.permiso
UNION ALL SELECT 'rol_modulo_permiso', COUNT(*) FROM core.rol_modulo_permiso
UNION ALL SELECT 'auth_refresh_sessions', COUNT(*) FROM core.auth_refresh_sessions;

-- Validar columnas clave del nuevo esquema
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'core'
  AND (
    (table_name='contacto' AND column_name IN ('nombres','apellido_paterno','tipo_documento','numero_documento'))
    OR (table_name='organizacion' AND column_name IN ('tipo_organizacion','rut','dv'))
    OR (table_name='usuario' AND column_name IN ('created_at','updated_at','contacto_id'))
  )
ORDER BY table_name, column_name;

-- Orfandad (debe dar 0)
SELECT COUNT(*) AS usuarios_sin_contacto
FROM core.usuario u
LEFT JOIN core.contacto c ON c.contacto_id = u.contacto_id
WHERE c.contacto_id IS NULL;

SELECT COUNT(*) AS org_contacto_invalido
FROM core.organizacion_contacto oc
LEFT JOIN core.organizacion o ON o.organizacion_id = oc.organizacion_id
LEFT JOIN core.contacto c ON c.contacto_id = oc.contacto_id
WHERE o.organizacion_id IS NULL OR c.contacto_id IS NULL;