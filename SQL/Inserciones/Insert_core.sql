-- Insertar tipo de contacto
INSERT INTO tipo_contacto (tipo_contacto_id, nombre, descripcion) VALUES (1, 'Persona', 'Contacto personal');
INSERT INTO tipo_contacto (tipo_contacto_id, nombre, descripcion) VALUES (2, 'Empresa', 'Contacto empresarial');

-- Insertar contacto
INSERT INTO contacto (nombre, direccion, celular, correo, redes_sociales, url, imagen_base64, tipo_contacto_id)
VALUES ('Juan Pérez', 'Calle Falsa 123', '987654321', 'juan@correo.com', '@juan', 'http://juan.com', NULL, 1);

-- Insertar organización
INSERT INTO organizacion (organizacion_id, razon_social, rut, dv, giro, logo_base64, contacto_id)
VALUES (1, 'Empresa Ejemplo S.A.', '12345678', '9', 'Servicios', NULL, 1);

-- Insertar cuenta bancaria
INSERT INTO cuenta_bancaria (cuenta_id, nombre_titular, banco, numero, correo_contacto, rut_titular, organizacion_id)
VALUES (1, 'Empresa Ejemplo S.A.', 'Banco Ejemplo', '111222333', 'finanzas@ejemplo.com', '12345678-9', 1);

-- Insertar sistema
INSERT INTO sistema (sistema_id, nombre, descripcion, activo)
VALUES (1, 'ERP', 'Sistema de gestión empresarial', true);

-- Insertar módulo
INSERT INTO modulo (modulo_id, nombre, descripcion, activo, sistema_id)
VALUES (1, 'Acceso', 'Gestión de accesos', true, 1);

-- Insertar organización_sistema
INSERT INTO organizacion_sistema (organizacion_id, sistema_id) VALUES (1, 1);

-- Insertar rol
INSERT INTO rol (nombre, descripcion) VALUES ('Administrador', 'Acceso total');

-- Insertar permiso
INSERT INTO permiso (nombre, descripcion, codigo, activo) VALUES ('Ver usuarios', 'Puede ver usuarios', 'USR_VIEW', true);

-- Insertar modulo_permiso
INSERT INTO modulo_permiso (modulo_id, permiso_id) VALUES (1, 1);

-- Insertar rol_modulo_permiso
INSERT INTO rol_modulo_permiso (rol_id, modulo_id, permiso_id) VALUES (1, 1, 1);

-- Insertar usuario
INSERT INTO usuario (username, password_hash, fecha_creacion, activo, fecha_actualizacion, contacto_id)
VALUES ('admin', 'hash123', CURRENT_DATE, true, CURRENT_DATE, 1);

-- Insertar usuario_rol
INSERT INTO usuario_rol (usuario_id, rol_id) VALUES (1, 1);

-- Insertar organizacion_contacto
INSERT INTO organizacion_contacto (contacto_id, organizacion_id) VALUES (1, 1);