-- =============================================================================
-- Datos de Prueba - ERP Core (adaptado a 01_init_core.sql actual)
-- =============================================================================

SET search_path TO core, media, public;

-- Requerido para crypt() y gen_salt() usados en passwords.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
-- 1) TIPOS 
-- ============================================
INSERT INTO core.tipo_contacto (tipo_contacto_id, nombre, descripcion) VALUES
(1, 'Personal', 'Contacto de persona natural'),
(2, 'Empresa', 'Contacto empresarial'),
(3, 'Proveedor', 'Contacto de proveedor'),
(4, 'Cliente', 'Contacto de cliente'),
(5, 'Empleado', 'Contacto de empleado')
ON CONFLICT (tipo_contacto_id) DO NOTHING;

INSERT INTO core.tipo_direccion_organizacion (codigo, nombre) VALUES
('TRIBUTARIA',  'Dirección Tributaria'),
('CASA_MATRIZ', 'Casa Matriz'),
('SUCURSAL',    'Sucursal'),
('BODEGA',      'Bodega'),
('ATENCION',    'Punto de Atención')
ON CONFLICT (codigo) DO NOTHING;

-- ============================================
-- 2) CONTACTOS (nueva estructura: nombres/apellidos, sin url)
-- ============================================
INSERT INTO core.contacto (
  contacto_id, nombres, apellido_paterno, apellido_materno,
  direccion, celular, correo, redes_sociales, tipo_contacto_id
) VALUES
(1, 'Sebastian',   'Parra',     NULL, 'Av. Libertador 1234, Santiago', '+56912345678', 'parra.sebastian91@gmail.com', '{"twitter":"@juanp","linkedin":"juanperez"}', 2),
(2, 'Paula',    'Gonzalez',  NULL, 'Calle Principal 567, Valparaiso', '+56987654321', 'paula.gonzalez@email.com', '{"linkedin":"paulagonzalez"}', 5),
(3, 'Diego',    'Fuentes',   NULL, 'Av. Apoquindo 3000, Las Condes', '+56223456789', 'diego.fuentes@email.com', '{"linkedin":"diegofuentes"}', 5),
(4, 'Camila',   'Rojas',     NULL, 'Los Carrera 890, Maipu', '+56224567890', 'camila.rojas@email.com', '{}'::jsonb, 5),
(5, 'Francisco','Morales',   NULL, 'Av. Pedro de Valdivia 1500, Providencia', '+56225678901', 'francisco.morales@email.com', '{"linkedin":"franciscomorales"}', 5),
(6, 'Ana',      'Martinez',  NULL, 'Las Condes 234, Santiago', '+56998765432', 'ana.martinez@email.com', '{}'::jsonb, 5),
(7, 'Carlos',   'Rojas',     NULL, 'Nunoa 456, Santiago', '+56976543210', 'carlos.rojas@email.com', '{"linkedin":"carlosrojas"}', 5),
(8, 'Valentina','Soto',      NULL, 'Vitacura 2800, Santiago', '+56226789012', 'valentina.soto@email.com', '{"linkedin":"valentinasoto"}', 5),
(9, 'Ignacio',  'Paredes',   NULL, 'Huerfanos 1234, Santiago Centro', '+56227890123', 'ignacio.paredes@email.com', '{}'::jsonb, 5),
(10,'Pedro',    'Silva',     NULL, 'San Miguel 789, Santiago', '+56965432109', 'pedro.silva@email.com', '{}'::jsonb, 5)
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
(5, 'Distribuidora Central', 'JURIDICA', '80567890', 'K', 'Distribución y Logística', false),
(6, 'Financiera Andina SpA', 'JURIDICA', '81678901', '2', 'Servicios de factoring y financiamiento', true),
(7, 'Capital Norte Factoring Ltda', 'JURIDICA', '82789012', '3', 'Financiamiento para pymes', true)
ON CONFLICT (organizacion_id) DO NOTHING;

WITH direcciones(org_id, tipo_codigo, calle, numero, depto_oficina, comuna, ciudad, region, codigo_postal, pais, referencia, es_principal, activo) AS (
    VALUES
    -- Organizacion 1
    (1, 'TRIBUTARIA',  'Av. Libertador Bernardo O''Higgins', '1234', NULL, 'Santiago', 'Santiago', 'RM', '8320000', 'CL', 'Oficina contabilidad', true,  true),
    (1, 'CASA_MATRIZ', 'Av. Apoquindo',                        '4501', 'Piso 12', 'Las Condes', 'Santiago', 'RM', '7550000', 'CL', 'Torre A',               true,  true),
    (1, 'BODEGA',      'Camino Lo Boza',                       '980',  NULL, 'Pudahuel', 'Santiago', 'RM', '9020000', 'CL', 'Centro logistico',         true,  true),
    (1, 'ATENCION',    'Providencia',                          '2100', NULL, 'Providencia', 'Santiago', 'RM', '7500000', 'CL', 'Sucursal atencion',       true,  true),

    -- Organizacion 2
    (2, 'TRIBUTARIA',  'Calle Blanco',                         '456',  NULL, 'Valparaiso', 'Valparaiso', 'Valparaiso', '2340000', 'CL', NULL, true, true),
    (2, 'CASA_MATRIZ', 'Av. Argentina',                        '789',  NULL, 'Valparaiso', 'Valparaiso', 'Valparaiso', '2340000', 'CL', NULL, true, true),
    (2, 'BODEGA',      'Ruta 68 KM 92',                        NULL,   NULL, 'Casablanca', 'Valparaiso', 'Valparaiso', '2480000', 'CL', 'Bodega principal', true, true),

    -- Organizacion 3
    (3, 'TRIBUTARIA',  'Av. Pedro Aguirre Cerda',              '1500', NULL, 'San Miguel', 'Santiago', 'RM', '8900000', 'CL', NULL, true, true),
    (3, 'CASA_MATRIZ', 'Av. Pedro de Valdivia',                '999',  'Of. 401', 'Providencia', 'Santiago', 'RM', '7500000', 'CL', NULL, true, true),
    (3, 'SUCURSAL',    'Av. Espana',                           '320',  NULL, 'Concepcion', 'Concepcion', 'Biobio', '4030000', 'CL', NULL, true, true),

    -- Organizacion 4
    (4, 'TRIBUTARIA',  'Nueva de Lyon',                        '145',  'Of. 602', 'Providencia', 'Santiago', 'RM', '7500000', 'CL', NULL, true, true),
    (4, 'CASA_MATRIZ', 'Avenida Vitacura',                     '2800', NULL, 'Vitacura', 'Santiago', 'RM', '7630000', 'CL', NULL, true, true),
    (4, 'ATENCION',    'Av. Irarrazaval',                      '5400', NULL, 'Nunoa', 'Santiago', 'RM', '7760000', 'CL', 'Mesa de ayuda', true, true),

    -- Organizacion 5
    (5, 'TRIBUTARIA',  'Av. Matta',                            '2210', NULL, 'Santiago', 'Santiago', 'RM', '8330000', 'CL', NULL, true, true),
    (5, 'BODEGA',      'Panamericana Norte KM 12',             NULL,   NULL, 'Quilicura', 'Santiago', 'RM', '8700000', 'CL', 'Patio de carga', true, true),

    -- Organizacion 6 (Financiadora)
    (6, 'TRIBUTARIA',  'Av. Apoquindo',                        '5400', 'Piso 8', 'Las Condes', 'Santiago', 'RM', '7550000', 'CL', 'Casa matriz tributaria', true, true),
    (6, 'CASA_MATRIZ', 'Av. Apoquindo',                        '5400', 'Piso 8', 'Las Condes', 'Santiago', 'RM', '7550000', 'CL', NULL, true, true),

    -- Organizacion 7 (Financiadora)
    (7, 'TRIBUTARIA',  'Cerro El Plomo',                       '5630', 'Of. 1201', 'Las Condes', 'Santiago', 'RM', '7550000', 'CL', 'Torre financiera', true, true),
    (7, 'CASA_MATRIZ', 'Cerro El Plomo',                       '5630', 'Of. 1201', 'Las Condes', 'Santiago', 'RM', '7550000', 'CL', NULL, true, true)
)
INSERT INTO core.organizacion_direccion (
    organizacion_id, tipo_direccion_id, calle, numero, depto_oficina, comuna, ciudad, region,
    codigo_postal, pais, referencia, es_principal, activo
)
SELECT
    d.org_id,
    t.tipo_direccion_id,
    d.calle, d.numero, d.depto_oficina, d.comuna, d.ciudad, d.region,
    d.codigo_postal, d.pais, d.referencia, d.es_principal, d.activo
FROM direcciones d
JOIN core.organizacion o
  ON o.organizacion_id = d.org_id
JOIN core.tipo_direccion_organizacion t
  ON t.codigo = d.tipo_codigo
WHERE NOT EXISTS (
    SELECT 1
    FROM core.organizacion_direccion od
    WHERE od.organizacion_id = d.org_id
      AND od.tipo_direccion_id = t.tipo_direccion_id
      AND od.calle = d.calle
      AND COALESCE(od.numero, '') = COALESCE(d.numero, '')
);

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
(5, 2,  'Contacto administrativo', false),
(6, 2,  'Lider comercial', true),
(6, 4,  'Ejecutiva senior', false),
(6, 6,  'Ejecutiva de cuentas', false),
(6, 8,  'Ejecutiva pymes', false),
(7, 3,  'Lider comercial', true),
(7, 5,  'Ejecutivo senior', false),
(7, 7,  'Ejecutivo de cuentas', false),
(7, 9,  'Ejecutiva pymes', false)
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
(5, 'Distribuidora Central', '80567890-K', 'Banco Scotiabank', '44556677889', 'cuentas@distribuidoracentral.cl'),
(6, 'Financiera Andina SpA', '81678901-2', 'Banco de Chile', '110022003344', 'tesoreria@financieraandina.cl'),
(7, 'Capital Norte Factoring Ltda', '82789012-3', 'Banco BCI', '220033004455', 'tesoreria@capitalnorte.cl');

-- ============================================
-- 6) SISTEMAS / MÓDULOS / FUNCIONALIDADES
-- ============================================

INSERT INTO core.sistema (sistema_id, nombre, "path", descripcion, activo, icono) 
VALUES(1, 'Factoring', '/factoring', 'Gestion de tus facturas', true, 'bolt')
ON CONFLICT (sistema_id) DO NOTHING;

INSERT INTO core.modulo (modulo_id, nombre, "path", descripcion, activo, sistema_id, icono) VALUES
(1, 'Dashboard', '/dashboard-facturas', 'Informacion general de tu gestion', true, 1, NULL),
(2, 'Publicador', '/publicador-facturas', 'Publica tus facturas para financiarlas', true, 1, NULL),
(3, 'Ofertas', '/offers', 'Gestion de ofertas de financiamiento', true, 1, NULL)
ON CONFLICT (modulo_id) DO NOTHING;


INSERT INTO core.funcionalidad (funcionalidad_id, nombre, descripcion, path, modulo_id, activo) VALUES
(1, 'Resumen de negocio', 'KPIs y estado de facturas', '/dashboard-facturas/overview', 1, true),
(2, 'Facturas por vencer', 'Monitoreo de vencimientos', '/dashboard-facturas/vencimientos', 1, true),
(3, 'Publicar factura', 'Carga y publicacion de factura', '/publicador-facturas/publicar', 2, true),
(4, 'Validacion de factura', 'Revision previa a publicacion', '/publicador-facturas/validar', 2, true),
(5, 'Bandeja de ofertas', 'Gestion de ofertas recibidas', '/offers/bandeja', 3, true),
(6, 'Detalle de oferta', 'Analisis y aceptacion de ofertas', '/offers/detalle', 3, true)
ON CONFLICT (funcionalidad_id) DO NOTHING;

INSERT INTO core.organizacion_sistema (organizacion_id, sistema_id) VALUES
(1,1),
(2,1),
(3,1),
(4,1),
(5,1),
(6,1),
(7,1)
ON CONFLICT (organizacion_id, sistema_id) DO NOTHING;

-- ============================================
-- 7) RBAC (estructura actual: rol(nombre,codigo) y permiso(per_nombre,per_cod))
-- ============================================
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(1, 'Ver Usuarios', 'USR_VIEW', 'Permiso para ver usuarios', true, 'VIEW'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(2, 'Crear Usuarios', 'USR_CREATE', 'Permiso para crear usuarios', true, 'CREATE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(3, 'Editar Usuarios', 'USR_EDIT', 'Permiso para editar usuarios', true, 'UPDATE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(4, 'Eliminar Usuarios', 'USR_DELETE', 'Permiso para eliminar usuarios', true, 'DELETE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(5, 'Ver Contactos', 'CNT_VIEW', 'Permiso para ver contactos', true, 'VIEW'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(6, 'Crear Contactos', 'CNT_CREATE', 'Permiso para crear contactos', true, 'CREATE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(7, 'Editar Contactos', 'CNT_EDIT', 'Permiso para editar contactos', true, 'UPDATE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(8, 'Eliminar Contactos', 'CNT_DELETE', 'Permiso para eliminar contactos', true, 'DELETE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(9, 'Ver Organizaciones', 'ORG_VIEW', 'Permiso para ver organizaciones', true, 'VIEW'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(10, 'Administrar Sistema', 'SYS_ADMIN', 'Permiso para administrar el sistema', true, 'VIEW'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(15, 'Crear Item', 'ITM_CREATE', 'Permiso para crear ítems', true, 'CREATE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(16, 'Ver Item', 'ITM_VIEW', 'Permiso para ver ítems', true, 'VIEW'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(17, 'Editar Item', 'ITM_EDIT', 'Permiso para editar ítems', true, 'UPDATE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(18, 'Eliminar Item', 'ITM_DELETE', 'Permiso para eliminar ítems', true, 'DELETE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(19, 'Leer Menu', 'MENU_VIEW', 'Permiso para leer el menú', true, 'VIEW'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(20, 'Ver Facturas', 'FCT_VEW', 'Permiso para ver Facturas publicadas', true, 'VIEW'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(21, 'Crear Facturas', 'FCT__CREATE', 'Permiso para crear publicar facturas', true, 'CREATE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(22, 'Editar Facturas', 'FCT_EDIT', 'Permiso para editar facturas publicadas', true, 'UPDATE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(23, 'Eliminar Facturas', 'FCT_DELETE', 'Permiso para eliminar facturas publicadas', true, 'DELETE'::core."permiso_tipo");
INSERT INTO core.permiso (permiso_id, per_nombre, per_cod, per_desc, per_activo, "permiso_tipo") VALUES(24, 'Solo Lectura', 'READ_ONLY', 'Permisos para solo lectura', true, 'VIEW'::core."permiso_tipo");

INSERT INTO core.rol (rol_id, nombre, codigo, descripcion) VALUES
(1, 'Super Administrador', 'SUPER_ADMIN', 'Rol con acceso total'),
(2, 'Administrador', 'ADMIN', 'Rol con permisos de administración'),
(3, 'Usuario Estándar', 'USR_STD', 'Rol con permisos estándar'),
(4, 'Supervisor', 'SUPERVISOR', 'Rol con permisos de supervisión'),
(5, 'Solo Lectura', 'READ_ONLY', 'Rol con permisos de solo lectura'),
(6, 'Cliente Cedente', 'CLIENTE_CEDENTE', 'Empresa que vende sus facturas en el portal'),
(7, 'Ejecutivo Financiadora', 'EJECUTIVO_FINANCIADORA', 'Ejecutivo de una financiadora que oferta sobre facturas'),
(8, 'Administrador Financiadora', 'ADMIN_FINANCIADORA', 'Administrador de una organización financiadora'),
(9, 'Administrador Cedente', 'ADMIN_CEDENTE', 'Administrador de una organización cedente');
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
(3, 1, 5), (3, 2, 5), (3, 3, 5),
(4, 3, 5), (4, 3, 6), (4, 3, 7),
(5, 1, 5), (5, 2, 5), (5, 3, 5)
ON CONFLICT (rol_id, modulo_id, permiso_id) DO NOTHING;

-- ============================================
-- 8) USUARIOS (contacto_id es UNIQUE y NOT NULL)
-- ============================================
INSERT INTO core.usuario (usuario_id, username, password_hash, activo, contacto_id) VALUES
(1, 'sparra',    '$2b$10$fIes8RyzzulG1X2PU91EEOQqmR6UWS63xbejElSXwTnQu3hW6m2/O', true, 1),
(2, 'pgonzalez', crypt('usuario123'::text, gen_salt('bf'::text, 10)), true, 2),
(3, 'dfuentes',  crypt('usuario123'::text, gen_salt('bf'::text, 10)), true, 3),
(4, 'crojas',    crypt('usuario123'::text, gen_salt('bf'::text, 10)), true, 4),
(5, 'fmorales',  crypt('usuario123'::text, gen_salt('bf'::text, 10)), true, 5),
(6, 'amartinez', crypt('usuario123'::text, gen_salt('bf'::text, 10)), true, 6),
(7, 'crojas2',   crypt('usuario123'::text, gen_salt('bf'::text, 10)), true, 7),
(8, 'vsoto',     crypt('usuario123'::text, gen_salt('bf'::text, 10)), true, 8),
(9, 'iparedes',  crypt('usuario123'::text, gen_salt('bf'::text, 10)), true, 9),
(10,'psilva',    crypt('usuario123'::text, gen_salt('bf'::text, 10)), true,10)
ON CONFLICT (usuario_id) DO NOTHING;

-- Mantiene password original del usuario 1. El resto queda con password usuario123.
UPDATE core.usuario
SET password_hash = crypt('usuario123'::text, gen_salt('bf'::text, 10))
WHERE usuario_id BETWEEN 2 AND 10;

DELETE FROM core.usuario_rol
WHERE usuario_id BETWEEN 2 AND 9;

INSERT INTO core.usuario_rol (usuario_id, rol_id) VALUES
(1,1),
(2,4),
(3,4),
(4,3),
(5,3),
(6,3),
(7,3),
(8,3),
(9,3),
(10,5)
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- ============================================
-- 8.1) GRUPOS DE TRABAJO FINANCIADORAS
-- 2 financiadoras, 2 lideres (rol Supervisor), 3 ejecutivos por grupo (rol Usuario Estandar)
-- ============================================
INSERT INTO core.grupo_trabajo (grupo_id, nombre, descripcion, lider_usuario_uuid, organizacion_id, activo, grupo_metadata)
SELECT
  '60000000-0000-0000-0000-000000000001'::uuid,
  'Equipo Andina Santiago',
  'Equipo comercial de Financiera Andina',
  u.usuario_uuid,
  o.organizacion_uuid,
  true,
  '{"tipo":"financiadora","zona":"metropolitana"}'::jsonb
FROM core.usuario u
JOIN core.organizacion o ON o.organizacion_id = 6
WHERE u.usuario_id = 2
ON CONFLICT (grupo_id) DO UPDATE SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  lider_usuario_uuid = EXCLUDED.lider_usuario_uuid,
  organizacion_id = EXCLUDED.organizacion_id,
  activo = EXCLUDED.activo,
  grupo_metadata = EXCLUDED.grupo_metadata;

INSERT INTO core.grupo_trabajo (grupo_id, nombre, descripcion, lider_usuario_uuid, organizacion_id, activo, grupo_metadata)
SELECT
  '70000000-0000-0000-0000-000000000001'::uuid,
  'Equipo Capital Norte',
  'Equipo comercial de Capital Norte Factoring',
  u.usuario_uuid,
  o.organizacion_uuid,
  true,
  '{"tipo":"financiadora","zona":"norte"}'::jsonb
FROM core.usuario u
JOIN core.organizacion o ON o.organizacion_id = 7
WHERE u.usuario_id = 3
ON CONFLICT (grupo_id) DO UPDATE SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  lider_usuario_uuid = EXCLUDED.lider_usuario_uuid,
  organizacion_id = EXCLUDED.organizacion_id,
  activo = EXCLUDED.activo,
  grupo_metadata = EXCLUDED.grupo_metadata;

INSERT INTO core.grupo_miembro (miembro_id, grupo_id, usuario_uuid, jefe_directo_id, cargo_en_grupo, grupo_metadata, active)
SELECT
  '60000000-0000-0000-0000-000000000011'::uuid,
  '60000000-0000-0000-0000-000000000001'::uuid,
  u.usuario_uuid,
  NULL,
  'Lider de equipo',
  '{"rol":"lider"}'::jsonb,
  true
FROM core.usuario u
WHERE u.usuario_id = 2
ON CONFLICT (grupo_id, usuario_uuid) DO UPDATE SET
  jefe_directo_id = EXCLUDED.jefe_directo_id,
  cargo_en_grupo = EXCLUDED.cargo_en_grupo,
  grupo_metadata = EXCLUDED.grupo_metadata,
  active = EXCLUDED.active;

INSERT INTO core.grupo_miembro (miembro_id, grupo_id, usuario_uuid, jefe_directo_id, cargo_en_grupo, grupo_metadata, active)
SELECT
  x.miembro_id,
  '60000000-0000-0000-0000-000000000001'::uuid,
  u.usuario_uuid,
  '60000000-0000-0000-0000-000000000011'::uuid,
  'Ejecutivo de cuentas',
  '{"rol":"ejecutivo"}'::jsonb,
  true
FROM (VALUES
  (4, '60000000-0000-0000-0000-000000000012'::uuid),
  (6, '60000000-0000-0000-0000-000000000013'::uuid),
  (8, '60000000-0000-0000-0000-000000000014'::uuid)
) AS x(usuario_id, miembro_id)
JOIN core.usuario u ON u.usuario_id = x.usuario_id
ON CONFLICT (grupo_id, usuario_uuid) DO UPDATE SET
  jefe_directo_id = EXCLUDED.jefe_directo_id,
  cargo_en_grupo = EXCLUDED.cargo_en_grupo,
  grupo_metadata = EXCLUDED.grupo_metadata,
  active = EXCLUDED.active;

INSERT INTO core.grupo_miembro (miembro_id, grupo_id, usuario_uuid, jefe_directo_id, cargo_en_grupo, grupo_metadata, active)
SELECT
  '70000000-0000-0000-0000-000000000011'::uuid,
  '70000000-0000-0000-0000-000000000001'::uuid,
  u.usuario_uuid,
  NULL,
  'Lider de equipo',
  '{"rol":"lider"}'::jsonb,
  true
FROM core.usuario u
WHERE u.usuario_id = 3
ON CONFLICT (grupo_id, usuario_uuid) DO UPDATE SET
  jefe_directo_id = EXCLUDED.jefe_directo_id,
  cargo_en_grupo = EXCLUDED.cargo_en_grupo,
  grupo_metadata = EXCLUDED.grupo_metadata,
  active = EXCLUDED.active;

INSERT INTO core.grupo_miembro (miembro_id, grupo_id, usuario_uuid, jefe_directo_id, cargo_en_grupo, grupo_metadata, active)
SELECT
  x.miembro_id,
  '70000000-0000-0000-0000-000000000001'::uuid,
  u.usuario_uuid,
  '70000000-0000-0000-0000-000000000011'::uuid,
  'Ejecutivo de cuentas',
  '{"rol":"ejecutivo"}'::jsonb,
  true
FROM (VALUES
  (5, '70000000-0000-0000-0000-000000000012'::uuid),
  (7, '70000000-0000-0000-0000-000000000013'::uuid),
  (9, '70000000-0000-0000-0000-000000000014'::uuid)
) AS x(usuario_id, miembro_id)
JOIN core.usuario u ON u.usuario_id = x.usuario_id
ON CONFLICT (grupo_id, usuario_uuid) DO UPDATE SET
  jefe_directo_id = EXCLUDED.jefe_directo_id,
  cargo_en_grupo = EXCLUDED.cargo_en_grupo,
  grupo_metadata = EXCLUDED.grupo_metadata,
  active = EXCLUDED.active;

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

-- Integridad de roles y permisos por usuario

SELECT
  u.usuario_id,
  u.username,
  string_agg(DISTINCT r.nombre, ', ' ORDER BY r.nombre) AS roles,
  string_agg(DISTINCT p.per_cod, ', ' ORDER BY p.per_cod) AS permisos
FROM core.usuario u
LEFT JOIN core.usuario_rol ur ON ur.usuario_id = u.usuario_id
LEFT JOIN core.rol r ON r.rol_id = ur.rol_id
LEFT JOIN core.rol_modulo_permiso rmp ON rmp.rol_id = r.rol_id
LEFT JOIN core.permiso p ON p.permiso_id = rmp.permiso_id
WHERE u.username = :username
GROUP BY u.usuario_id, u.username;

