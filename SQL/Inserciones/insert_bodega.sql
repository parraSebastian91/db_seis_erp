-- Marcas
INSERT INTO marca (marca_id, marca_nombre, marca_desc) VALUES (1, 'Nike', 'Marca deportiva');
INSERT INTO marca (marca_id, marca_nombre, marca_desc) VALUES (2, 'Adidas', 'Marca deportiva');

-- Tipos
INSERT INTO tipo (tipo_id, tipo_nombre, tipo_desc) VALUES (1, 'Polera', 'Ropa superior');
INSERT INTO tipo (tipo_id, tipo_nombre, tipo_desc) VALUES (2, 'Pantalón', 'Ropa inferior');

-- Categorías
INSERT INTO categoria (cat_id, cat_nombre, cat_desc, tipo_id) VALUES (1, 'Deportiva', 'Ropa para deporte', 1);
INSERT INTO categoria (cat_id, cat_nombre, cat_desc, tipo_id) VALUES (2, 'Casual', 'Ropa casual', 2);

-- Subcategorías
INSERT INTO sub_categoria (sub_cat_id, sub_cat_nombre, sub_cat_desc, cat_id) VALUES (1, 'Running', 'Para correr', 1);
INSERT INTO sub_categoria (sub_cat_id, sub_cat_nombre, sub_cat_desc, cat_id) VALUES (2, 'Jeans', 'Denim', 2);

-- Tallas
INSERT INTO size_item (size, size_orden) VALUES ('S', 1);
INSERT INTO size_item (size, size_orden) VALUES ('M', 2);

-- Relación talla-tipo
INSERT INTO size_tipo (size_id, tipo_id) VALUES (1, 1);
INSERT INTO size_tipo (size_id, tipo_id) VALUES (2, 2);

-- Ubicaciones
INSERT INTO ubicacion (nombre, descripcion, tipo, pasillo, rack, estante) VALUES ('Bodega Central', 'Principal', 'Bodega', 'A', '1', '1');
INSERT INTO ubicacion (nombre, descripcion, tipo, pasillo, rack, estante) VALUES ('Sucursal 1', 'Sucursal', 'Sucursal', 'B', '2', '2');

-- Items
INSERT INTO item (item_nombre, item_stock, item_sublimable, item_img_base64, marca_id, tipo_id, cat_id, sub_cat_id, size_id, org_id)
VALUES ('Polera Nike S', 100, true, NULL, 1, 1, 1, 1, 1, 1);

INSERT INTO item (item_nombre, item_stock, item_sublimable, item_img_base64, marca_id, tipo_id, cat_id, sub_cat_id, size_id, org_id)
VALUES ('Pantalón Adidas M', 50, false, NULL, 2, 2, 2, 2, 2, 1);

-- Stock
INSERT INTO stock (item_id, ubicacion_id, cantidad) VALUES (1, 1, 80);
INSERT INTO stock (item_id, ubicacion_id, cantidad) VALUES (2, 2, 40);

-- Tipos de movimiento
INSERT INTO tipo_movimiento (nombre, afecta_stock) VALUES ('Ingreso', true);
INSERT INTO tipo_movimiento (nombre, afecta_stock) VALUES ('Egreso', true);

-- Usuario
INSERT INTO usuario (usu_username, usu_password, usu_creacion, usu_activo, usu_update, contacto_id, rol)
VALUES ('bodega_admin', 'hashpass', CURRENT_DATE, true, CURRENT_DATE, 1, 1);

-- Movimiento
INSERT INTO movimiento (item_id, tipo_movimiento_id, cantidad, fecha, ubicacion_origen_id, ubicacion_destino_id, motivo, usuario_id)
VALUES (1, 1, 20, now(), NULL, 1, 'Ingreso inicial', 1);

-- Inventario físico
INSERT INTO inventario_fisico (fecha, observaciones, usuario_id)
VALUES (CURRENT_DATE, 'Conteo inicial', 1);

-- Ajuste de inventario
INSERT INTO ajuste_inventario (inventario_fisico_id, item_id, ubicacion_id, stock_actual, stock_fisico, diferencia)
VALUES (1, 1, 1, 80, 80, 0);