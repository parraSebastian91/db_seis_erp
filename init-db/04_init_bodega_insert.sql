
-- Catálogos base

INSERT INTO bodega.bodega
(bodega_id, bodega_nombre, ubicacion)
VALUES(1, 'central', 'pedro mira 820');

INSERT INTO costo (costo, costo_id, fecha_inicio, fecha_termino, item_id) values
(100, 1, now(), null , 1000),
(100, 2, now(), null , 1001),
(100, 3, now(), null , 1002),

INSERT INTO bodega.marca (marca_id, marca_nombre, marca_desc) VALUES
 (10, 'Nike', 'Deportiva'),
 (11, 'Adidas', 'Performance'),
 (12, 'Puma', 'Sportstyle');

INSERT INTO bodega.tipo (tipo_id, tipo_nombre, tipo_desc) VALUES
 (100, 'Polera', 'Parte superior'),
 (101, 'Pantalón', 'Parte inferior');

INSERT INTO bodega.categoria (cat_id, cat_nombre, cat_desc, tipo_id) VALUES
 (200, 'Training', 'Entrenamiento', 100),
 (201, 'Casual', 'Uso diario', 100),
 (202, 'Outdoor', 'Exterior', 101);

INSERT INTO bodega.sub_categoria (sub_cat_id, sub_cat_nombre, sub_cat_desc, cat_id) VALUES
 (300, 'Running', 'Correr', 200),
 (301, 'Lifestyle', 'Moda', 201),
 (302, 'Trekking', 'Montaña', 202);

-- Sizes
INSERT INTO bodega.size_item (size_id, size, size_orden) VALUES
 (1, 'XS', 0),
 (2, 'S', 1),
 (3, 'M', 2),
 (4, 'L', 3);

-- Relación M:M size \- tipo
INSERT INTO bodega.size_tipo (size_id, tipo_id) VALUES
 (1, 100), (2, 100), (3, 100), (4, 100),
 (2, 101), (3, 101), (4, 101);

-- Ubicaciones
INSERT INTO bodega.ubicacion (id, nombre, descripcion, tipo, pasillo, rack, estante) VALUES
 (1, 'Bodega Central', 'Principal', 'BODEGA', 'A', '1', '1'),
 (2, 'Sucursal Norte', 'Regional', 'SUCURSAL', 'B', '2', '1');

-- Tipos de movimiento
INSERT INTO bodega.tipo_movimiento (id, nombre, afecta_stock) VALUES
 (1, 'Ingreso', true),
 (2, 'Egreso', true),
 (3, 'Ajuste', true);

-- Items
INSERT INTO bodega.item (item_id, item_nombre, item_sublimable, item_img_base64, marca_id, tipo_id, cat_id, sub_cat_id, size_id, org_id)
VALUES
 (1000, 'Polera Nike XS', true, NULL, 10, 100, 200, 300, 1, 1),
 (1001, 'Polera Adidas M', true, NULL, 11, 100, 201, 301, 3, 1),
 (1002, 'Pantalón Puma L', false, NULL, 12, 101, 202, 302, 4, 1);

-- Stock inicial
INSERT INTO bodega.stock ( item_id, ubicacion_id, cantidad) VALUES
 ( 1000, 1, 50),
 ( 1001, 1, 30),
 ( 1002, 2, 20);

-- Movimientos (ingresos)
INSERT INTO bodega.movimiento (id, item_id, tipo_movimiento_id, cantidad, fecha, ubicacion_origen_id, ubicacion_destino_id, motivo, usuario_id)
VALUES
 (1, 1000, 1, 50, now(), NULL, 1, 'Carga inicial', 1),
 (2, 1001, 1, 30, now(), NULL, 1, 'Carga inicial', 1),
 (3, 1002, 1, 20, now(), NULL, 2, 'Carga inicial', 1);

-- Inventario físico y ajuste
INSERT INTO bodega.inventario_fisico (id, fecha, observaciones, usuario_id)
VALUES (1, CURRENT_DATE, 'Conteo apertura', 1);

INSERT INTO bodega.ajuste_inventario (id, inventario_fisico_id , item_id, ubicacion_id, stock_actual, stock_fisico, diferencia)
VALUES
 (1, 1, 1000, 1, 50, 50, 0),
 (2, 1, 1001, 1, 30, 28, -2),
 (3, 1, 1002, 2, 20, 22, 2);

INSERT INTO bodega.bodega
(bodega_id, bodega_nombre, ubicacion)
VALUES(1, 'central', 'pedro mira 820');
