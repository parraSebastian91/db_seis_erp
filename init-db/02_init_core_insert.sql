-- =============================================================================
-- Datos de Prueba - ERP Core
-- =============================================================================

SET search_path TO core,public;

-- ============================================
-- 1. TIPOS DE CONTACTO
-- ============================================

INSERT INTO core.tipo_contacto VALUES (1, 'Personal', 'Contacto de persona natural');
INSERT INTO core.tipo_contacto VALUES (2, 'Empresa', 'Contacto empresarial');
INSERT INTO core.tipo_contacto VALUES (3, 'Proveedor', 'Contacto de proveedor');
INSERT INTO core.tipo_contacto VALUES (4, 'Cliente', 'Contacto de cliente');
INSERT INTO core.tipo_contacto VALUES (5, 'Empleado', 'Contacto de empleado');

-- ============================================
-- 2. CONTACTOS
-- ============================================
INSERT INTO core.contacto (nombre, direccion, celular, correo, redes_sociales, url, tipo_contacto_id) VALUES
('Juan Pérez', 'Av.  Libertador 1234, Santiago', '+56912345678', 'juan.perez@email.com', '{"twitter": "@juanp", "linkedin": "juanperez"}', 'https://juanperez.com', 2),
('María González', 'Calle Principal 567, Valparaíso', '+56987654321', 'maria.gonzalez@email.com', '{"instagram": "@mariag"}', NULL, 2),
('TechSupply SpA', 'Av.  Apoquindo 3000, Las Condes', '+56223456789', 'contacto@techsupply.cl', '{"linkedin": "techsupply"}', 'https://techsupply.cl', 3),
('Distribuidora Los Andes', 'Los Carrera 890, Maipú', '+56224567890', 'ventas@losandes.cl', NULL, 'https://losandes.cl', 3),
('Comercial Pacific', 'Av. Pedro de Valdivia 1500, Providencia', '+56225678901', 'info@pacific.cl', '{"facebook": "pacificchile"}', 'https://pacific.cl', 4),
('Ana Martínez', 'Las Condes 234, Santiago', '+56998765432', 'ana.martinez@email.com', NULL, NULL, 5),
('Carlos Rojas', 'Ñuñoa 456, Santiago', '+56976543210', 'carlos.rojas@email.com', '{"linkedin": "carlosrojas"}', NULL, 5),
('Softech Consulting', 'Vitacura 2800, Santiago', '+56226789012', 'contact@softech.cl', '{"linkedin": "softech", "twitter": "@softech"}', 'https://softech.cl', 1),
('Constructora Norte', 'Huérfanos 1234, Santiago Centro', '+56227890123', 'contacto@norte.cl', NULL, 'https://construccionnorte.cl', 4),
('Pedro Silva', 'San Miguel 789, Santiago', '+56965432109', 'pedro.silva@email.com', NULL, NULL, 2);

-- ============================================
-- 3. ORGANIZACIONES
-- ============================================
INSERT INTO core.organizacion (razon_social, rut, dv, giro, contacto_id, activo) VALUES
('Empresa Demo S.A.', '76123456', '7', 'Servicios de Tecnología', 8, true),
('Comercial Sur Limitada', '77234567', '8', 'Comercio al por Mayor', 5, true),
('Industrias del Pacífico S.A.', '78345678', '9', 'Manufactura Industrial', 3, true),
('Servicios Profesionales SpA', '79456789', '0', 'Consultoría y Asesorías', 1, true),
('Distribuidora Central', '80567890', 'K', 'Distribución y Logística', 4, false);

-- ============================================
-- 4. ORGANIZACION_CONTACTO (relación muchos a muchos)
-- ============================================
INSERT INTO core.organizacion_contacto (contacto_id, organizacion_id) VALUES
(8, 1), -- Softech trabaja con Empresa Demo
(1, 1), -- Juan Pérez en Empresa Demo
(6, 1), -- Ana Martínez en Empresa Demo
(7, 1), -- Carlos Rojas en Empresa Demo
(5, 2), -- Comercial Pacific es contacto de Comercial Sur
(9, 2), -- Constructora Norte trabaja con Comercial Sur
(3, 3), -- TechSupply provee a Industrias del Pacífico
(4, 3), -- Distribuidora Los Andes trabaja con Industrias del Pacífico
(1, 4), -- Juan Pérez en Servicios Profesionales
(10, 4), -- Pedro Silva en Servicios Profesionales
(4, 5), -- Distribuidora Los Andes es contacto de Distribuidora Central
(2, 5); -- María González en Distribuidora Central

-- ============================================
-- 5. CUENTAS BANCARIAS
-- ============================================
INSERT INTO core.cuenta_bancaria (nombre_titular, banco, numero, correo_contacto, rut_titular, organizacion_id) VALUES
('Empresa Demo S.A.', 'Banco de Chile', '12345678901', 'finanzas@empresademo.cl', '76123456-7', 1),
('Empresa Demo S.A.', 'Banco Estado', '98765432109', 'tesoreria@empresademo.cl', '76123456-7', 1),
('Comercial Sur Limitada', 'Banco Santander', '11223344556', 'pagos@comercialsur.cl', '77234567-8', 2),
('Industrias del Pacífico S. A.', 'Banco BCI', '55667788990', 'contabilidad@industriaspacifico.cl', '78345678-9', 3),
('Servicios Profesionales SpA', 'Banco Itaú', '99887766554', 'admin@serviciospro.cl', '79456789-0', 4),
('Distribuidora Central', 'Banco Scotiabank', '44556677889', 'cuentas@distribuidoracentral.cl', '80567890-K', 5);

-- ============================================
-- 6. SISTEMAS
-- ============================================
INSERT INTO core.sistema (nombre, path, descripcion, activo) VALUES
('ERP Core', '/erp', 'Sistema central de planificación de recursos empresariales', true),
('CRM', '/crm', 'Sistema de gestión de relaciones con clientes', true),
('HRM', '/hrm', 'Sistema de gestión de recursos humanos', true),
('Finanzas', '/finance', 'Sistema de gestión financiera y contable', true),
('Inventario', '/inventory', 'Sistema de gestión de inventarios y almacenes', true),
('Reportería', '/reports', 'Sistema de reportes y analytics', false);

-- ============================================
-- 7. MÓDULOS
-- ============================================
INSERT INTO core.modulo (nombre, path, descripcion, activo, sistema_id) VALUES
-- Módulos ERP Core
('Administración', '/admin', 'Gestión de usuarios y configuración', true, 1),
('Organizaciones', '/organizations', 'Gestión de empresas y contactos', true, 1),
('Seguridad', '/security', 'Control de accesos y permisos', true, 1),
-- Módulos CRM
('Clientes', '/customers', 'Gestión de clientes y prospectos', true, 2),
('Ventas', '/sales', 'Gestión de oportunidades y cotizaciones', true, 2),
('Marketing', '/marketing', 'Campañas y seguimiento', true, 2),
-- Módulos HRM
('Empleados', '/employees', 'Gestión de personal', true, 3),
('Nómina', '/payroll', 'Procesamiento de sueldos', true, 3),
('Evaluaciones', '/evaluations', 'Evaluaciones de desempeño', true, 3),
-- Módulos Finanzas
('Contabilidad', '/accounting', 'Libro diario y mayor', true, 4),
('Tesorería', '/treasury', 'Flujo de caja y pagos', true, 4),
('Facturación', '/billing', 'Emisión de documentos tributarios', true, 4),
-- Módulos Inventario
('Almacenes', '/warehouses', 'Gestión de bodegas', true, 5),
('Productos', '/products', 'Catálogo de productos', true, 5),
('Compras', '/purchases', 'Órdenes de compra', true, 5);

-- ============================================
-- 8. FUNCIONALIDADES
-- ============================================
INSERT INTO core. funcionalidad (nombre, descripcion, path, modulo_id, activo) VALUES
-- Funcionalidades de Administración
('Gestión de Usuarios', 'Crear, editar y eliminar usuarios', '/admin/users', 1, true),
('Configuración del Sistema', 'Parámetros generales del sistema', '/admin/settings', 1, true),
('Logs del Sistema', 'Auditoría y registros de actividad', '/admin/logs', 1, true),
-- Funcionalidades de Organizaciones
('Gestión de Empresas', 'ABM de organizaciones', '/organizations/companies', 2, true),
('Gestión de Contactos', 'ABM de contactos', '/organizations/contacts', 2, true),
('Cuentas Bancarias', 'Gestión de cuentas bancarias', '/organizations/bank-accounts', 2, true),
-- Funcionalidades de Seguridad
('Roles y Permisos', 'Configuración de perfiles de acceso', '/security/roles', 3, true),
('Auditoría de Accesos', 'Registro de ingresos al sistema', '/security/audit', 3, true),
-- Funcionalidades CRM
('Ficha de Cliente', 'Información detallada del cliente', '/customers/profile', 4, true),
('Historial de Interacciones', 'Registro de comunicaciones', '/customers/history', 4, true),
('Pipeline de Ventas', 'Embudo de conversión', '/sales/pipeline', 5, true),
('Cotizaciones', 'Generación de cotizaciones', '/sales/quotes', 5, true),
('Campañas Email', 'Envío masivo de correos', '/marketing/campaigns', 6, true),
-- Funcionalidades HRM
('Ficha de Empleado', 'Datos personales y laborales', '/employees/profile', 7, true),
('Control de Asistencia', 'Registro de entrada y salida', '/employees/attendance', 7, true),
('Cálculo de Nómina', 'Procesamiento de remuneraciones', '/payroll/calculate', 8, true),
('Liquidaciones', 'Generación de liquidaciones de sueldo', '/payroll/settlements', 8, true),
-- Funcionalidades Finanzas
('Libro Diario', 'Registro de asientos contables', '/accounting/journal', 10, true),
('Balance', 'Estados financieros', '/accounting/balance', 10, true),
('Flujo de Caja', 'Proyección de ingresos y egresos', '/treasury/cashflow', 11, true),
('Factura Electrónica', 'Emisión de facturas DTE', '/billing/invoice', 12, true),
-- Funcionalidades Inventario
('Stock por Bodega', 'Visualización de existencias', '/warehouses/stock', 13, true),
('Catálogo de Productos', 'Listado de productos', '/products/catalog', 14, true),
('Orden de Compra', 'Generación de OC', '/purchases/orders', 15, true);

-- ============================================
-- 9. ORGANIZACION_SISTEMA (relación muchos a muchos)
-- ============================================
INSERT INTO core.organizacion_sistema (organizacion_id, sistema_id) VALUES
(1, 1), -- Empresa Demo usa ERP Core
(1, 2), -- Empresa Demo usa CRM
(1, 3), -- Empresa Demo usa HRM
(1, 4), -- Empresa Demo usa Finanzas
(2, 1), -- Comercial Sur usa ERP Core
(2, 2), -- Comercial Sur usa CRM
(2, 5), -- Comercial Sur usa Inventario
(3, 1), -- Industrias del Pacífico usa ERP Core
(3, 4), -- Industrias del Pacífico usa Finanzas
(3, 5), -- Industrias del Pacífico usa Inventario
(4, 1), -- Servicios Profesionales usa ERP Core
(4, 2), -- Servicios Profesionales usa CRM
(5, 1), -- Distribuidora Central usa ERP Core
(5, 5); -- Distribuidora Central usa Inventario

-- ============================================
-- 10. PERMISOS
-- ============================================
INSERT INTO core.permiso VALUES (1, 'Ver Usuarios', 'Puede visualizar usuarios', 'USR_VIEW', true);
INSERT INTO core.permiso VALUES (2, 'Crear Usuarios', 'Puede crear nuevos usuarios', 'USR_CREATE', true);
INSERT INTO core.permiso VALUES (3, 'Editar Usuarios', 'Puede modificar usuarios existentes', 'USR_EDIT', true);
INSERT INTO core.permiso VALUES (5, 'Ver Contactos', 'Puede visualizar contactos', 'CNT_VIEW', true);
INSERT INTO core.permiso VALUES (6, 'Crear Contactos', 'Puede crear nuevos contactos', 'CNT_CREATE', true);
INSERT INTO core.permiso VALUES (7, 'Editar Contactos', 'Puede modificar contactos', 'CNT_EDIT', true);
INSERT INTO core.permiso VALUES (8, 'Eliminar Contactos', 'Puede eliminar contactos', 'CNT_DELETE', false);
INSERT INTO core.permiso VALUES (9, 'Ver Organizaciones', 'Puede visualizar organizaciones', 'ORG_VIEW', true);
INSERT INTO core.permiso VALUES (12, 'Crear Bodegas', 'Puede Crear nuevas bodegas', 'BDG_CREATE', true);
INSERT INTO core.permiso VALUES (13, 'Editar Bodegas', 'Puede Editar informacion de bodegas', 'BDG_EDIT', true);
INSERT INTO core.permiso VALUES (14, 'Eliminar Bodegas', 'Puede Eliminar bodegas', 'BDG_DELETE', true);
INSERT INTO core.permiso VALUES (10, 'Administrar Sistema', 'Puede administrar configuraciones del sistema', 'SYS_ADMIN', true);
INSERT INTO core.permiso VALUES (11, 'Ver Bodegas', 'Puede Listar bodegas', 'BDG_VIEW', true);
INSERT INTO core.permiso VALUES (4, 'Eliminar Usuarios', 'Puede eliminar usuarios', 'USR_DELETE', false);
INSERT INTO core.permiso VALUES (15, 'Crear Item', 'Puede Crear Item', 'ITM_CREATE', true);
INSERT INTO core.permiso VALUES (16, 'Ver Iitem', 'Puede visualizar Item', 'ITM_VIEW', true);
INSERT INTO core.permiso VALUES (17, 'Editar Item', 'Puede modificar item existentes', 'ITM_EDIT', true);
INSERT INTO core.permiso VALUES (18, 'Eliminar item', 'Puede eliminar item', 'ITM_DELETE', true);
INSERT INTO core.permiso VALUES (19, 'Leer Menu', 'Puede ver menu de shell', 'MENU_VIEW', true);

-- ============================================
-- 11. ROLES
-- ============================================
INSERT INTO core.rol VALUES (1, 'Super Administrador', 'Acceso completo a todo el sistema', 'SUPER_ADMIN');
INSERT INTO core.rol VALUES (2, 'Administrador', 'Acceso administrativo limitado', 'ADMIN');
INSERT INTO core.rol VALUES (3, 'Usuario Estándar', 'Acceso básico de usuario', 'USR_STD');
INSERT INTO core.rol VALUES (4, 'Supervisor', 'Supervisión de operaciones', 'SUPERVISOR');
INSERT INTO core.rol VALUES (5, 'Solo Lectura', 'Solo puede consultar información', 'READ_ONLY');

-- ============================================
-- 12. ROL_MODULO_PERMISO
-- ============================================
-- Administrador del Sistema - Acceso total
INSERT INTO core.rol_modulo_permiso (rol_id, modulo_id, permiso_id) 
SELECT 1, m.modulo_id, p.permiso_id 
FROM core.modulo m 
CROSS JOIN core.permiso p 
WHERE p.per_activo = true;

-- Gerente General - Todos los módulos excepto configuración de seguridad
INSERT INTO core.rol_modulo_permiso (rol_id, modulo_id, permiso_id) VALUES
-- Organizaciones
(2, 2, 1), (2, 2, 2), (2, 2, 3), (2, 2, 5),
-- CRM
(2, 4, 1), (2, 4, 2), (2, 4, 3), (2, 4, 5),
(2, 5, 1), (2, 5, 2), (2, 5, 3), (2, 5, 7),
(2, 6, 1), (2, 6, 2), (2, 6, 3),
-- Finanzas
(2, 10, 2), (2, 10, 5),
(2, 11, 2), (2, 11, 7),
(2, 12, 2), (2, 12, 5);

-- Jefe de Ventas
INSERT INTO core.rol_modulo_permiso (rol_id, modulo_id, permiso_id) VALUES
(3, 4, 1), (3, 4, 2), (3, 4, 3), (3, 4, 5),
(3, 5, 1), (3, 5, 2), (3, 5, 3), (3, 5, 5), (3, 5, 7),
(3, 6, 1), (3, 6, 2), (3, 6, 3), (3, 6, 5),
(3, 12, 1), (3, 12, 2); -- Facturación

-- Vendedor
INSERT INTO core.rol_modulo_permiso (rol_id, modulo_id, permiso_id) VALUES
(4, 4, 1), (4, 4, 2), (4, 4, 3),
(4, 5, 1), (4, 5, 2), (4, 5, 3),
(4, 12, 1), (4, 12, 2);

-- Contador
INSERT INTO core.rol_modulo_permiso (rol_id, modulo_id, permiso_id) VALUES
(5, 10, 1), (5, 10, 2), (5, 10, 3), (5, 10, 5),
(5, 11, 1), (5, 11, 2), (5, 11, 3), (5, 11, 5), (5, 11, 7),
(5, 12, 1), (5, 12, 2), (5, 12, 3), (5, 12, 5), (5, 12, 9);

-- Jefe de RRHH
INSERT INTO core. rol_modulo_permiso (rol_id, modulo_id, permiso_id) VALUES
(6, 7, 1), (6, 7, 2), (6, 7, 3), (6, 7, 4), (6, 7, 5),
(6, 8, 1), (6, 8, 2), (6, 8, 3), (6, 8, 5), (6, 8, 7),
(6, 9, 1), (6, 9, 2), (6, 9, 3), (6, 9, 5);

-- Empleado (solo lectura básica)
INSERT INTO core.rol_modulo_permiso (rol_id, modulo_id, permiso_id) VALUES
(7, 7, 2), -- Ver empleados
(7, 8, 2); -- Ver nómina

-- Jefe de Bodega
INSERT INTO core. rol_modulo_permiso (rol_id, modulo_id, permiso_id) VALUES
(8, 13, 1), (8, 13, 2), (8, 13, 3), (8, 13, 5),
(8, 14, 1), (8, 14, 2), (8, 14, 3), (8, 14, 5),
(8, 15, 1), (8, 15, 2), (8, 15, 3), (8, 15, 5), (8, 15, 7);

-- Operador de Bodega
INSERT INTO core.rol_modulo_permiso (rol_id, modulo_id, permiso_id) VALUES
(9, 13, 1), (9, 13, 2), (9, 13, 3),
(9, 14, 2),
(9, 15, 2);

-- Auditor (solo lectura)
INSERT INTO core.rol_modulo_permiso (rol_id, modulo_id, permiso_id) 
SELECT 10, m.modulo_id, 2 -- Permiso LEER
FROM core.modulo m 
WHERE m.activo = true;

-- ============================================
-- 13. USUARIOS
-- ============================================
-- Contraseña: "Password123!" hasheada con bcrypt
INSERT INTO core.usuario (username, password_hash, fecha_creacion, activo, contacto_id) VALUES
('sparra', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-01-15', true, 1),
('jperez', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-01-15', true, 1),
('mgonzalez', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-01-20', true, 2),
('amartinez', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-02-01', true, 6),
('crojas', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-02-05', true, 7),
('psilva', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-02-10', true, 10),
('vendedor1', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-02-15', true, NULL),
('contador1', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-02-20', true, NULL),
('bodeguero1', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-03-01', true, NULL),
('auditor1', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-03-05', true, NULL),
('inactivo', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '2025-01-01', false, NULL);

-- ============================================
-- 14. USUARIO_ROL
-- ============================================
INSERT INTO core.usuario_rol (usuario_id, rol_id) VALUES
(1, 1), -- admin es Administrador del Sistema
(2, 2), -- jperez es Gerente General
(2, 4), -- jperez también es Jefe de Ventas
(3, 3), -- mgonzalez es Vendedor
(4, 4), -- amartinez es Jefe de RRHH
(5, 3), -- crojas es Empleado
(6, 5), -- psilva es Contador
(7, 3), -- vendedor1 es Vendedor
(8, 5), -- contador1 es Contador
(9, 4), -- bodeguero1 es Jefe de Bodega
(10, 5); -- auditor1 es Auditor

-- ============================================
-- 15. SESIONES DE REFRESH (Ejemplos)
-- ============================================
INSERT INTO auth_refresh_sessions 
(user_id, device_type, device_fingerprint, refresh_token_hash, ip, user_agent, expires_at, last_used_at) 
VALUES
(1, 'desktop', 'fp_admin_desktop_001', '$2a$10$abcdefghijklmnopqrstuvwxyz1234567890', '192.168.1.100', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', now() + interval '30 days', now()),
(2, 'mobile', 'fp_jperez_iphone_001', '$2a$10$zyxwvutsrqponmlkjihgfedcba0987654321', '192.168.1.101', 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0)', now() + interval '30 days', now() - interval '2 hours'),
(3, 'desktop', 'fp_mgonzalez_chrome_001', '$2a$10$111222333444555666777888999000aaabbb', '192.168.1.102', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120', now() + interval '30 days', now() - interval '1 day'),
(4, 'tablet', 'fp_amartinez_ipad_001', '$2a$10$cccdddeeefffggghhhiiijjjkkklllmmm', '192.168.1.103', 'Mozilla/5.0 (iPad; CPU OS 14_0)', now() + interval '30 days', now() - interval '3 hours');

-- =============================================================================
-- CONSULTAS DE VERIFICACIÓN
-- =============================================================================

-- Ver resumen de datos insertados
SELECT 
  'Tipos de Contacto' as tabla, COUNT(*) as registros FROM core.tipo_contacto
UNION ALL
SELECT 'Contactos', COUNT(*) FROM core.contacto
UNION ALL
SELECT 'Organizaciones', COUNT(*) FROM core.organizacion
UNION ALL
SELECT 'Cuentas Bancarias', COUNT(*) FROM core.cuenta_bancaria
UNION ALL
SELECT 'Sistemas', COUNT(*) FROM core.sistema
UNION ALL
SELECT 'Módulos', COUNT(*) FROM core.modulo
UNION ALL
SELECT 'Funcionalidades', COUNT(*) FROM core.funcionalidad
UNION ALL
SELECT 'Permisos', COUNT(*) FROM core.permiso
UNION ALL
SELECT 'Roles', COUNT(*) FROM core.rol
UNION ALL
SELECT 'Usuarios', COUNT(*) FROM core.usuario
UNION ALL
SELECT 'Sesiones Refresh', COUNT(*) FROM auth_refresh_sessions;

-- Ver usuarios con sus roles
SELECT 
  u.usuario_id,
  u.username,
  c.nombre as nombre_contacto,
  STRING_AGG(r.nombre, ', ') as roles,
  u.activo
FROM core.usuario u
LEFT JOIN core.contacto c ON u.contacto_id = c.contacto_id
LEFT JOIN core.usuario_rol ur ON u.usuario_id = ur.usuario_id
LEFT JOIN core.rol r ON ur.rol_id = r.rol_id
GROUP BY u.usuario_id, u.username, c.nombre, u.activo
ORDER BY u.usuario_id;

-- Ver organizaciones con sus sistemas
SELECT 
  o.razon_social,
  o. rut || '-' || o. dv as rut_completo,
  STRING_AGG(s.nombre, ', ') as sistemas_contratados,
  o.activo
FROM core.organizacion o
LEFT JOIN core.organizacion_sistema os ON o.organizacion_id = os.organizacion_id
LEFT JOIN core.sistema s ON os. sistema_id = s.sistema_id
GROUP BY o.organizacion_id, o.razon_social, o.rut, o.dv, o.activo
ORDER BY o.organizacion_id;

-- Ver permisos por rol y módulo
SELECT 
  r. nombre as rol,
  m.nombre as modulo,
  STRING_AGG(p.per_nombre, ', ') as permisos
FROM core.rol r
JOIN core.rol_modulo_permiso rmp ON r.rol_id = rmp.rol_id
JOIN core.modulo m ON rmp. modulo_id = m.modulo_id
JOIN core.permiso p ON rmp.permiso_id = p. permiso_id
GROUP BY r.rol_id, r.nombre, m.modulo_id, m.nombre
ORDER BY r.nombre, m.nombre;