-- =============================================================================
-- 16_init_geo_normalizado.sql
-- Jerarquía geográfica completa: Región (nivel 1) → Provincia (2) → Comuna (3)
-- + Refactorización de organizacion_direccion:
--     - FK normalizada (comuna_id) en lugar de texto libre
--     - Desacoplamiento de organizacion mediante tabla relacional
--
-- DEPENDE DE: 01_init_core.sql, 12_init_org_perfil.sql
-- =============================================================================

SET search_path TO public, core;

-- ============================================================================
-- PARTE 1: Extender division_admin con soporte jerárquico multi-nivel
-- ============================================================================

-- nivel:              1=Región/Estado, 2=Provincia/Condado, 3=Comuna/Municipio
-- parent_division_id: apunta a la división padre (nivel-1 para nivel=2, etc.)

ALTER TABLE core.division_admin
    ADD COLUMN IF NOT EXISTS nivel SMALLINT NOT NULL DEFAULT 1
        CHECK (nivel BETWEEN 1 AND 3),
    ADD COLUMN IF NOT EXISTS parent_division_id BIGINT
        REFERENCES core.division_admin(division_id) ON DELETE SET NULL;

COMMENT ON COLUMN core.division_admin.nivel IS
    '1=Región/Estado, 2=Provincia/Condado, 3=Comuna/Municipio/Localidad';
COMMENT ON COLUMN core.division_admin.parent_division_id IS
    'División padre inmediata: nivel=2 → su región; nivel=3 → su provincia';

-- Índices para navegación descendente y filtrado
CREATE INDEX IF NOT EXISTS idx_division_parent
    ON core.division_admin (parent_division_id)
    WHERE parent_division_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_division_nivel_pais
    ON core.division_admin (pais_id, nivel)
    WHERE activo = true;

-- ============================================================================
-- PARTE 2: Datos — Provincias y Comunas de Chile
-- Fuente: JSON adjunto con codificación ISO 3166-2:CL
-- Los códigos de región ya existen en division_admin (cargados en script 12).
-- ============================================================================

-- 2a. PROVINCIAS (nivel=2) ─────────────────────────────────────────────────
--     Cada fila referencia la región (nivel=1) por su código de 2-3 letras.
--
--     Nota de mapping: el DB usa 'OH' para O'Higgins (el JSON usa 'LI')
--                       y 'LB' para Aysén (el JSON usa 'AI')

WITH cl_regiones AS (
    SELECT da.division_id, da.codigo
    FROM core.division_admin da
    JOIN core.pais p ON p.pais_id = da.pais_id
    WHERE p.codigo = 'CL' AND da.nivel = 1
)
INSERT INTO core.division_admin (pais_id, codigo, nombre, nivel_nombre, nivel, parent_division_id)
SELECT
    (SELECT pais_id FROM core.pais WHERE codigo = 'CL'),
    prov.codigo, prov.nombre, 'Provincia', 2, r.division_id
FROM (VALUES
    -- Arica y Parinacota (AP)
    ('ap01', 'Arica',                    'AP'),
    ('ap02', 'Parinacota',               'AP'),
    -- Tarapacá (TA)
    ('ta01', 'Iquique',                  'TA'),
    ('ta02', 'Tamarugal',                'TA'),
    -- Antofagasta (AN)
    ('an01', 'Antofagasta',              'AN'),
    ('an02', 'El Loa',                   'AN'),
    ('an03', 'Tocopilla',                'AN'),
    -- Atacama (AT)
    ('at01', 'Copiapó',                  'AT'),
    ('at02', 'Chañaral',                 'AT'),
    ('at03', 'Huasco',                   'AT'),
    -- Coquimbo (CO)
    ('co01', 'Elqui',                    'CO'),
    ('co02', 'Choapa',                   'CO'),
    ('co03', 'Limarí',                   'CO'),
    -- Valparaíso (VS)
    ('vs01', 'Valparaíso',               'VS'),
    ('vs02', 'Isla de Pascua',           'VS'),
    ('vs03', 'Los Andes',                'VS'),
    ('vs04', 'Petorca',                  'VS'),
    ('vs05', 'Quillota',                 'VS'),
    ('vs06', 'San Antonio',              'VS'),
    ('vs07', 'San Felipe de Aconcagua',  'VS'),
    ('vs08', 'Marga Marga',              'VS'),
    -- O'Higgins (DB: OH / JSON: LI)
    ('li01', 'Cachapoal',                'OH'),
    ('li02', 'Cardenal Caro',            'OH'),
    ('li03', 'Colchagua',                'OH'),
    -- Maule (ML)
    ('ml01', 'Talca',                    'ML'),
    ('ml02', 'Cauquenes',                'ML'),
    ('ml03', 'Curicó',                   'ML'),
    ('ml04', 'Linares',                  'ML'),
    -- Biobío (BI)
    ('bi01', 'Concepción',               'BI'),
    ('bi02', 'Arauco',                   'BI'),
    ('bi03', 'Biobío',                   'BI'),
    -- Ñuble (NB)
    ('nb01', 'Diguillín',                'NB'),
    ('nb02', 'Itata',                    'NB'),
    ('nb03', 'Punilla',                  'NB'),
    -- Araucanía (AR)
    ('ar01', 'Cautín',                   'AR'),
    ('ar02', 'Malleco',                  'AR'),
    -- Los Ríos (LR)
    ('lr01', 'Valdivia',                 'LR'),
    ('lr02', 'Ranco',                    'LR'),
    -- Los Lagos (LL)
    ('ll01', 'Llanquihue',               'LL'),
    ('ll02', 'Chiloé',                   'LL'),
    ('ll03', 'Osorno',                   'LL'),
    ('ll04', 'Palena',                   'LL'),
    -- Aysén (DB: LB / JSON: AI)
    ('ai01', 'Coyhaique',                'LB'),
    ('ai02', 'Aysén',                    'LB'),
    ('ai03', 'Capitán Pratt',            'LB'),
    ('ai04', 'General Carrera',          'LB'),
    -- Magallanes (MA)
    ('ma01', 'Magallanes',               'MA'),
    ('ma02', 'Antártica Chilena',        'MA'),
    ('ma03', 'Tierra del Fuego',         'MA'),
    ('ma04', 'Última Esperanza',         'MA'),
    -- Metropolitana (RM)
    ('rm01', 'Santiago',                 'RM'),
    ('rm02', 'Cordillera',               'RM'),
    ('rm03', 'Chacabuco',                'RM'),
    ('rm04', 'Maipo',                    'RM'),
    ('rm05', 'Mellipilla',               'RM'),
    ('rm06', 'Talagante',                'RM')
) AS prov(codigo, nombre, region_codigo)
JOIN cl_regiones r ON r.codigo = prov.region_codigo
ON CONFLICT (pais_id, codigo) DO NOTHING;

-- 2b. COMUNAS (nivel=3) ────────────────────────────────────────────────────

WITH cl_provincias AS (
    SELECT da.division_id, da.codigo
    FROM core.division_admin da
    JOIN core.pais p ON p.pais_id = da.pais_id
    WHERE p.codigo = 'CL' AND da.nivel = 2
)
INSERT INTO core.division_admin (pais_id, codigo, nombre, nivel_nombre, nivel, parent_division_id)
SELECT
    (SELECT pais_id FROM core.pais WHERE codigo = 'CL'),
    c.codigo, c.nombre, 'Comuna', 3, pr.division_id
FROM (VALUES
    -- ── ap01: Arica ──────────────────────────────────────────────────────
    ('ap0101', 'Arica',                     'ap01'),
    ('ap0102', 'Camarones',                 'ap01'),
    -- ── ap02: Parinacota ─────────────────────────────────────────────────
    ('ap0201', 'Putre',                     'ap02'),
    ('ap0202', 'General Lagos',             'ap02'),
    -- ── ta01: Iquique ─────────────────────────────────────────────────────
    ('ta0101', 'Iquique',                   'ta01'),
    ('ta0102', 'Alto Hospicio',             'ta01'),
    -- ── ta02: Tamarugal ───────────────────────────────────────────────────
    ('ta0201', 'Pozo Almonte',              'ta02'),
    ('ta0202', 'Camiña',                    'ta02'),
    ('ta0203', 'Colchane',                  'ta02'),
    ('ta0204', 'Huara',                     'ta02'),
    ('ta0205', 'Pica',                      'ta02'),
    -- ── an01: Antofagasta ─────────────────────────────────────────────────
    ('an0101', 'Antofagasta',               'an01'),
    ('an0102', 'Mejillones',                'an01'),
    ('an0103', 'Sierra Gorda',              'an01'),
    ('an0104', 'Taltal',                    'an01'),
    -- ── an02: El Loa ──────────────────────────────────────────────────────
    ('an0201', 'Calama',                    'an02'),
    ('an0202', 'Ollagüe',                   'an02'),
    ('an0203', 'San Pedro de Atacama',      'an02'),
    -- ── an03: Tocopilla ───────────────────────────────────────────────────
    ('an0301', 'Tocopilla',                 'an03'),
    ('an0302', 'María Elena',               'an03'),
    -- ── at01: Copiapó ─────────────────────────────────────────────────────
    ('at0101', 'Copiapó',                   'at01'),
    ('at0102', 'Caldera',                   'at01'),
    ('at0103', 'Tierra Amarilla',           'at01'),
    -- ── at02: Chañaral ────────────────────────────────────────────────────
    ('at0201', 'Chañaral',                  'at02'),
    ('at0202', 'Diego de Almagro',          'at02'),
    -- ── at03: Huasco ──────────────────────────────────────────────────────
    ('at0301', 'Vallenar',                  'at03'),
    ('at0302', 'Alto del Carmen',           'at03'),
    ('at0303', 'Freirina',                  'at03'),
    ('at0304', 'Huasco',                    'at03'),
    -- ── co01: Elqui ───────────────────────────────────────────────────────
    ('co0101', 'La Serena',                 'co01'),
    ('co0102', 'Coquimbo',                  'co01'),
    ('co0103', 'Andacollo',                 'co01'),
    ('co0104', 'La Higuera',                'co01'),
    ('co0105', 'Paiguano',                  'co01'),
    ('co0106', 'Vicuña',                    'co01'),
    -- ── co02: Choapa ──────────────────────────────────────────────────────
    ('co0201', 'Illapel',                   'co02'),
    ('co0202', 'Canela',                    'co02'),
    ('co0203', 'Los Vilos',                 'co02'),
    ('co0204', 'Salamanca',                 'co02'),
    -- ── co03: Limarí ──────────────────────────────────────────────────────
    ('co0301', 'Ovalle',                    'co03'),
    ('co0302', 'Combarbalá',                'co03'),
    ('co0303', 'Monte Patria',              'co03'),
    ('co0304', 'Punitaqui',                 'co03'),
    ('co0305', 'Río Hurtado',               'co03'),
    -- ── vs01: Valparaíso ──────────────────────────────────────────────────
    ('vs0101', 'Valparaíso',                'vs01'),
    ('vs0102', 'Casablanca',                'vs01'),
    ('vs0103', 'Concón',                    'vs01'),
    ('vs0104', 'Juan Fernández',            'vs01'),
    ('vs0105', 'Puchuncaví',                'vs01'),
    ('vs0107', 'Quintero',                  'vs01'),
    ('vs0109', 'Viña del Mar',              'vs01'),
    -- ── vs02: Isla de Pascua ──────────────────────────────────────────────
    ('vs0201', 'Isla de Pascua',            'vs02'),
    -- ── vs03: Los Andes ───────────────────────────────────────────────────
    ('vs0301', 'Los Andes',                 'vs03'),
    ('vs0302', 'Calle Larga',               'vs03'),
    ('vs0303', 'Rinconada',                 'vs03'),
    ('vs0304', 'San Esteban',               'vs03'),
    -- ── vs04: Petorca ─────────────────────────────────────────────────────
    ('vs0401', 'La Ligua',                  'vs04'),
    ('vs0402', 'Cabildo',                   'vs04'),
    ('vs0403', 'Papudo',                    'vs04'),
    ('vs0404', 'Petorca',                   'vs04'),
    ('vs0405', 'Zapallar',                  'vs04'),
    -- ── vs05: Quillota ────────────────────────────────────────────────────
    ('vs0501', 'Quillota',                  'vs05'),
    ('vs0502', 'Calera',                    'vs05'),
    ('vs0503', 'Hijuelas',                  'vs05'),
    ('vs0504', 'La Cruz',                   'vs05'),
    ('vs0506', 'Nogales',                   'vs05'),
    -- ── vs06: San Antonio ─────────────────────────────────────────────────
    ('vs0601', 'San Antonio',               'vs06'),
    ('vs0602', 'Algarrobo',                 'vs06'),
    ('vs0603', 'Cartagena',                 'vs06'),
    ('vs0604', 'El Quisco',                 'vs06'),
    ('vs0605', 'El Tabo',                   'vs06'),
    ('vs0606', 'Santo Domingo',             'vs06'),
    -- ── vs07: San Felipe de Aconcagua ─────────────────────────────────────
    ('vs0701', 'San Felipe',                'vs07'),
    ('vs0702', 'Catemu',                    'vs07'),
    ('vs0703', 'Llaillay',                  'vs07'),
    ('vs0704', 'Panquehue',                 'vs07'),
    ('vs0705', 'Putaendo',                  'vs07'),
    ('vs0706', 'Santa María',               'vs07'),
    -- ── vs08: Marga Marga ─────────────────────────────────────────────────
    ('vs0801', 'Quilpué',                   'vs08'),
    ('vs0802', 'Limache',                   'vs08'),
    ('vs0803', 'Olmué',                     'vs08'),
    ('vs0804', 'Villa Alemana',             'vs08'),
    -- ── li01: Cachapoal (O'Higgins) ───────────────────────────────────────
    ('li0101', 'Rancagua',                  'li01'),
    ('li0102', 'Codegua',                   'li01'),
    ('li0103', 'Coinco',                    'li01'),
    ('li0104', 'Coltauco',                  'li01'),
    ('li0105', 'Doñihue',                   'li01'),
    ('li0106', 'Graneros',                  'li01'),
    ('li0107', 'Las Cabras',                'li01'),
    ('li0108', 'Machalí',                   'li01'),
    ('li0109', 'Malloa',                    'li01'),
    ('li0110', 'Mostazal',                  'li01'),
    ('li0111', 'Olivar',                    'li01'),
    ('li0112', 'Peumo',                     'li01'),
    ('li0113', 'Pichidegua',                'li01'),
    ('li0114', 'Quinta de Tilcoco',         'li01'),
    ('li0115', 'Rengo',                     'li01'),
    ('li0116', 'Requínoa',                  'li01'),
    ('li0117', 'San Vicente',               'li01'),
    -- ── li02: Cardenal Caro ───────────────────────────────────────────────
    ('li0201', 'Pichilemu',                 'li02'),
    ('li0202', 'La Estrella',               'li02'),
    ('li0203', 'Litueche',                  'li02'),
    ('li0204', 'Marchihue',                 'li02'),
    ('li0205', 'Navidad',                   'li02'),
    ('li0206', 'Paredones',                 'li02'),
    -- ── li03: Colchagua ───────────────────────────────────────────────────
    ('li0301', 'San Fernando',              'li03'),
    ('li0302', 'Chépica',                   'li03'),
    ('li0303', 'Chimbarongo',               'li03'),
    ('li0304', 'Lolol',                     'li03'),
    ('li0305', 'Nancagua',                  'li03'),
    ('li0306', 'Palmilla',                  'li03'),
    ('li0307', 'Peralillo',                 'li03'),
    ('li0308', 'Placilla',                  'li03'),
    ('li0309', 'Pumanque',                  'li03'),
    ('li0310', 'Santa Cruz',                'li03'),
    -- ── ml01: Talca ───────────────────────────────────────────────────────
    ('ml0101', 'Talca',                     'ml01'),
    ('ml0102', 'Constitución',              'ml01'),
    ('ml0103', 'Curepto',                   'ml01'),
    ('ml0104', 'Empedrado',                 'ml01'),
    ('ml0105', 'Maule',                     'ml01'),
    ('ml0106', 'Pelarco',                   'ml01'),
    ('ml0107', 'Pencahue',                  'ml01'),
    ('ml0108', 'Río Claro',                 'ml01'),
    ('ml0109', 'San Clemente',              'ml01'),
    ('ml0110', 'San Rafael',                'ml01'),
    -- ── ml02: Cauquenes ───────────────────────────────────────────────────
    ('ml0201', 'Cauquenes',                 'ml02'),
    ('ml0202', 'Chanco',                    'ml02'),
    ('ml0203', 'Pelluhue',                  'ml02'),
    -- ── ml03: Curicó ──────────────────────────────────────────────────────
    ('ml0301', 'Curicó',                    'ml03'),
    ('ml0302', 'Hualañé',                   'ml03'),
    ('ml0303', 'Licantén',                  'ml03'),
    ('ml0304', 'Molina',                    'ml03'),
    ('ml0305', 'Rauco',                     'ml03'),
    ('ml0306', 'Romeral',                   'ml03'),
    ('ml0307', 'Sagrada Familia',           'ml03'),
    ('ml0308', 'Teno',                      'ml03'),
    ('ml0309', 'Vichuquén',                 'ml03'),
    -- ── ml04: Linares ─────────────────────────────────────────────────────
    ('ml0401', 'Linares',                   'ml04'),
    ('ml0402', 'Colbún',                    'ml04'),
    ('ml0403', 'Longaví',                   'ml04'),
    ('ml0404', 'Parral',                    'ml04'),
    ('ml0405', 'Retiro',                    'ml04'),
    ('ml0406', 'San Javier',                'ml04'),
    ('ml0407', 'Villa Alegre',              'ml04'),
    ('ml0408', 'Yerbas Buenas',             'ml04'),
    -- ── bi01: Concepción ──────────────────────────────────────────────────
    ('bi0101', 'Concepción',                'bi01'),
    ('bi0102', 'Coronel',                   'bi01'),
    ('bi0103', 'Chiguayante',               'bi01'),
    ('bi0104', 'Florida',                   'bi01'),
    ('bi0105', 'Hualqui',                   'bi01'),
    ('bi0106', 'Lota',                      'bi01'),
    ('bi0107', 'Penco',                     'bi01'),
    ('bi0108', 'San Pedro de la Paz',       'bi01'),
    ('bi0109', 'Santa Juana',               'bi01'),
    ('bi0110', 'Talcahuano',                'bi01'),
    ('bi0111', 'Tomé',                      'bi01'),
    ('bi0112', 'Hualpén',                   'bi01'),
    -- ── bi02: Arauco ──────────────────────────────────────────────────────
    ('bi0201', 'Lebu',                      'bi02'),
    ('bi0202', 'Arauco',                    'bi02'),
    ('bi0203', 'Cañete',                    'bi02'),
    ('bi0204', 'Contulmo',                  'bi02'),
    ('bi0205', 'Curanilahue',               'bi02'),
    ('bi0206', 'Los Álamos',                'bi02'),
    ('bi0207', 'Tirúa',                     'bi02'),
    -- ── bi03: Biobío ──────────────────────────────────────────────────────
    ('bi0301', 'Los Ángeles',               'bi03'),
    ('bi0302', 'Antuco',                    'bi03'),
    ('bi0303', 'Cabrero',                   'bi03'),
    ('bi0304', 'Laja',                      'bi03'),
    ('bi0305', 'Mulchén',                   'bi03'),
    ('bi0306', 'Nacimiento',                'bi03'),
    ('bi0307', 'Negrete',                   'bi03'),
    ('bi0308', 'Quilaco',                   'bi03'),
    ('bi0309', 'Quilleco',                  'bi03'),
    ('bi0310', 'San Rosendo',               'bi03'),
    ('bi0311', 'Santa Bárbara',             'bi03'),
    ('bi0312', 'Tucapel',                   'bi03'),
    ('bi0313', 'Yumbel',                    'bi03'),
    ('bi0314', 'Alto Biobío',               'bi03'),
    -- ── nb01: Diguillín ───────────────────────────────────────────────────
    ('nb0101', 'Bulnes',                    'nb01'),
    ('nb0102', 'Chillán',                   'nb01'),
    ('nb0103', 'Chillán Viejo',             'nb01'),
    ('nb0104', 'El Carmen',                 'nb01'),
    ('nb0105', 'Pemuco',                    'nb01'),
    ('nb0106', 'Pinto',                     'nb01'),
    ('nb0107', 'Quillón',                   'nb01'),
    ('nb0108', 'San Ignacio',               'nb01'),
    ('nb0109', 'Yungay',                    'nb01'),
    -- ── nb02: Itata ───────────────────────────────────────────────────────
    ('nb0201', 'Cobquecura',                'nb02'),
    ('nb0202', 'Coelemu',                   'nb02'),
    ('nb0203', 'Ninhue',                    'nb02'),
    ('nb0204', 'Portezuelo',                'nb02'),
    ('nb0205', 'Quirihue',                  'nb02'),
    ('nb0206', 'Ránquil',                   'nb02'),
    ('nb0207', 'Treguaco',                  'nb02'),
    -- ── nb03: Punilla ─────────────────────────────────────────────────────
    ('nb0301', 'Coihueco',                  'nb03'),
    ('nb0302', 'Ñiquén',                    'nb03'),
    ('nb0303', 'San Carlos',                'nb03'),
    ('nb0304', 'San Fabián',                'nb03'),
    ('nb0305', 'San Nicolás',               'nb03'),
    -- ── ar01: Cautín (Araucanía) ──────────────────────────────────────────
    ('ar0101', 'Temuco',                    'ar01'),
    ('ar0102', 'Carahue',                   'ar01'),
    ('ar0103', 'Cunco',                     'ar01'),
    ('ar0104', 'Curarrehue',                'ar01'),
    ('ar0105', 'Freire',                    'ar01'),
    ('ar0106', 'Galvarino',                 'ar01'),
    ('ar0107', 'Gorbea',                    'ar01'),
    ('ar0108', 'Lautaro',                   'ar01'),
    ('ar0109', 'Loncoche',                  'ar01'),
    ('ar0110', 'Melipeuco',                 'ar01'),
    ('ar0111', 'Nueva Imperial',            'ar01'),
    ('ar0112', 'Padre las Casas',           'ar01'),
    ('ar0113', 'Perquenco',                 'ar01'),
    ('ar0114', 'Pitrufquén',                'ar01'),
    ('ar0115', 'Pucón',                     'ar01'),
    ('ar0116', 'Saavedra',                  'ar01'),
    ('ar0117', 'Teodoro Schmidt',           'ar01'),
    ('ar0118', 'Toltén',                    'ar01'),
    ('ar0119', 'Vilcún',                    'ar01'),
    ('ar0120', 'Villarrica',                'ar01'),
    ('ar0121', 'Cholchol',                  'ar01'),
    -- ── ar02: Malleco ─────────────────────────────────────────────────────
    ('ar0201', 'Angol',                     'ar02'),
    ('ar0202', 'Collipulli',                'ar02'),
    ('ar0203', 'Curacautín',                'ar02'),
    ('ar0204', 'Ercilla',                   'ar02'),
    ('ar0205', 'Lonquimay',                 'ar02'),
    ('ar0206', 'Los Sauces',                'ar02'),
    ('ar0207', 'Lumaco',                    'ar02'),
    ('ar0208', 'Purén',                     'ar02'),
    ('ar0209', 'Renaico',                   'ar02'),
    ('ar0210', 'Traiguén',                  'ar02'),
    ('ar0211', 'Victoria',                  'ar02'),
    -- ── lr01: Valdivia ────────────────────────────────────────────────────
    ('lr0101', 'Valdivia',                  'lr01'),
    ('lr0102', 'Corral',                    'lr01'),
    ('lr0103', 'Lanco',                     'lr01'),
    ('lr0104', 'Los Lagos',                 'lr01'),
    ('lr0105', 'Máfil',                     'lr01'),
    ('lr0106', 'Mariquina',                 'lr01'),
    ('lr0107', 'Paillaco',                  'lr01'),
    ('lr0108', 'Panguipulli',               'lr01'),
    -- ── lr02: Ranco ───────────────────────────────────────────────────────
    ('lr0201', 'La Unión',                  'lr02'),
    ('lr0202', 'Futrono',                   'lr02'),
    ('lr0203', 'Lago Ranco',                'lr02'),
    ('lr0204', 'Río Bueno',                 'lr02'),
    -- ── ll01: Llanquihue ──────────────────────────────────────────────────
    ('ll0101', 'Puerto Montt',              'll01'),
    ('ll0102', 'Calbuco',                   'll01'),
    ('ll0103', 'Cochamó',                   'll01'),
    ('ll0104', 'Fresia',                    'll01'),
    ('ll0105', 'Frutillar',                 'll01'),
    ('ll0106', 'Los Muermos',               'll01'),
    ('ll0107', 'Llanquihue',                'll01'),
    ('ll0108', 'Maullín',                   'll01'),
    ('ll0109', 'Puerto Varas',              'll01'),
    -- ── ll02: Chiloé ──────────────────────────────────────────────────────
    ('ll0201', 'Castro',                    'll02'),
    ('ll0202', 'Ancud',                     'll02'),
    ('ll0203', 'Chonchi',                   'll02'),
    ('ll0204', 'Curaco de Vélez',           'll02'),
    ('ll0205', 'Dalcahue',                  'll02'),
    ('ll0206', 'Puqueldón',                 'll02'),
    ('ll0207', 'Queilén',                   'll02'),
    ('ll0208', 'Quellón',                   'll02'),
    ('ll0209', 'Quemchi',                   'll02'),
    ('ll0210', 'Quinchao',                  'll02'),
    -- ── ll03: Osorno ──────────────────────────────────────────────────────
    ('ll0301', 'Osorno',                    'll03'),
    ('ll0302', 'Puerto Octay',              'll03'),
    ('ll0303', 'Purranque',                 'll03'),
    ('ll0304', 'Puyehue',                   'll03'),
    ('ll0305', 'Río Negro',                 'll03'),
    ('ll0306', 'San Juan de la Costa',      'll03'),
    ('ll0307', 'San Pablo',                 'll03'),
    -- ── ll04: Palena ──────────────────────────────────────────────────────
    ('ll0401', 'Chaitén',                   'll04'),
    ('ll0402', 'Futaleufú',                 'll04'),
    ('ll0403', 'Hualaihué',                 'll04'),
    ('ll0404', 'Palena',                    'll04'),
    -- ── ai01: Coyhaique (Aysén, DB: LB) ──────────────────────────────────
    ('ai0101', 'Coyhaique',                 'ai01'),
    ('ai0102', 'Lago Verde',                'ai01'),
    -- ── ai02: Aysén ───────────────────────────────────────────────────────
    ('ai0201', 'Aisén',                     'ai02'),
    ('ai0202', 'Cisnes',                    'ai02'),
    ('ai0203', 'Guaitecas',                 'ai02'),
    -- ── ai03: Capitán Pratt ───────────────────────────────────────────────
    ('ai0301', 'Cochrane',                  'ai03'),
    ('ai0302', 'O''Higgins',                'ai03'),
    ('ai0303', 'Tortel',                    'ai03'),
    -- ── ai04: General Carrera ─────────────────────────────────────────────
    ('ai0401', 'Chile Chico',               'ai04'),
    ('ai0402', 'Río Ibáñez',                'ai04'),
    -- ── ma01: Magallanes ──────────────────────────────────────────────────
    ('ma0101', 'Punta Arenas',              'ma01'),
    ('ma0102', 'Laguna Blanca',             'ma01'),
    ('ma0103', 'Río Verde',                 'ma01'),
    ('ma0104', 'San Gregorio',              'ma01'),
    -- ── ma02: Antártica Chilena ───────────────────────────────────────────
    ('ma0201', 'Cabo de Hornos',            'ma02'),
    ('ma0202', 'Antártica',                 'ma02'),
    -- ── ma03: Tierra del Fuego ────────────────────────────────────────────
    ('ma0301', 'Porvenir',                  'ma03'),
    ('ma0302', 'Primavera',                 'ma03'),
    ('ma0303', 'Timaukel',                  'ma03'),
    -- ── ma04: Última Esperanza ────────────────────────────────────────────
    ('ma0401', 'Natales',                   'ma04'),
    ('ma0402', 'Torres del Paine',          'ma04'),
    -- ── rm01: Santiago ────────────────────────────────────────────────────
    ('rm0101', 'Santiago',                  'rm01'),
    ('rm0102', 'Cerrillos',                 'rm01'),
    ('rm0103', 'Cerro Navia',               'rm01'),
    ('rm0104', 'Conchalí',                  'rm01'),
    ('rm0105', 'El Bosque',                 'rm01'),
    ('rm0106', 'Estación Central',          'rm01'),
    ('rm0107', 'Huechuraba',                'rm01'),
    ('rm0108', 'Independencia',             'rm01'),
    ('rm0109', 'La Cisterna',               'rm01'),
    ('rm0110', 'La Florida',                'rm01'),
    ('rm0111', 'La Granja',                 'rm01'),
    ('rm0112', 'La Pintana',                'rm01'),
    ('rm0113', 'La Reina',                  'rm01'),
    ('rm0114', 'Las Condes',                'rm01'),
    ('rm0115', 'Lo Barnechea',              'rm01'),
    ('rm0116', 'Lo Espejo',                 'rm01'),
    ('rm0117', 'Lo Prado',                  'rm01'),
    ('rm0118', 'Macul',                     'rm01'),
    ('rm0119', 'Maipú',                     'rm01'),
    ('rm0120', 'Ñuñoa',                     'rm01'),
    ('rm0121', 'Pedro Aguirre Cerda',       'rm01'),
    ('rm0122', 'Peñalolén',                 'rm01'),
    ('rm0123', 'Providencia',               'rm01'),
    ('rm0124', 'Pudahuel',                  'rm01'),
    ('rm0125', 'Quilicura',                 'rm01'),
    ('rm0126', 'Quinta Normal',             'rm01'),
    ('rm0127', 'Recoleta',                  'rm01'),
    ('rm0128', 'Renca',                     'rm01'),
    ('rm0129', 'San Joaquín',               'rm01'),
    ('rm0130', 'San Miguel',                'rm01'),
    ('rm0131', 'San Ramón',                 'rm01'),
    ('rm0132', 'Vitacura',                  'rm01'),
    -- ── rm02: Cordillera ──────────────────────────────────────────────────
    ('rm0201', 'Puente Alto',               'rm02'),
    ('rm0202', 'Pirque',                    'rm02'),
    ('rm0203', 'San José de Maipo',         'rm02'),
    -- ── rm03: Chacabuco ───────────────────────────────────────────────────
    ('rm0301', 'Colina',                    'rm03'),
    ('rm0302', 'Lampa',                     'rm03'),
    ('rm0303', 'Tiltil',                    'rm03'),
    -- ── rm04: Maipo ───────────────────────────────────────────────────────
    ('rm0401', 'San Bernardo',              'rm04'),
    ('rm0402', 'Buin',                      'rm04'),
    ('rm0403', 'Calera de Tango',           'rm04'),
    ('rm0404', 'Paine',                     'rm04'),
    -- ── rm05: Mellipilla ──────────────────────────────────────────────────
    ('rm0501', 'Melipilla',                 'rm05'),
    ('rm0502', 'Alhué',                     'rm05'),
    ('rm0503', 'Curacaví',                  'rm05'),
    ('rm0504', 'María Pinto',               'rm05'),
    ('rm0505', 'San Pedro',                 'rm05'),
    -- ── rm06: Talagante ───────────────────────────────────────────────────
    ('rm0601', 'Talagante',                 'rm06'),
    ('rm0602', 'El Monte',                  'rm06'),
    ('rm0603', 'Isla de Maipo',             'rm06'),
    ('rm0604', 'Padre Hurtado',             'rm06'),
    ('rm0605', 'Peñaflor',                  'rm06')
) AS c(codigo, nombre, provincia_codigo)
JOIN cl_provincias pr ON pr.codigo = c.provincia_codigo
ON CONFLICT (pais_id, codigo) DO NOTHING;

-- ============================================================================
-- PARTE 3: Tabla relacional Organización ↔ Dirección
-- Desacopla organizacion de organizacion_direccion.
-- La dirección pasa a ser una entidad reutilizable (puede asociarse a más
-- de una org, p.ej. grupo empresarial en un mismo edificio).
-- ============================================================================

CREATE TABLE IF NOT EXISTS core.organizacion_tiene_direccion (
    id                BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    organizacion_id   BIGINT  NOT NULL
                      REFERENCES core.organizacion(organizacion_id) ON DELETE CASCADE,
    direccion_id      BIGINT  NOT NULL
                      REFERENCES core.organizacion_direccion(organizacion_direccion_id) ON DELETE CASCADE,
    tipo_direccion_id BIGINT
                      REFERENCES core.tipo_direccion_organizacion(tipo_direccion_id),
    es_principal      BOOLEAN NOT NULL DEFAULT false,
    activo            BOOLEAN NOT NULL DEFAULT true,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (organizacion_id, direccion_id)
);

COMMENT ON TABLE core.organizacion_tiene_direccion IS
    'Relación N:N entre organizaciones y direcciones. '
    'Una dirección puede pertenecer a varias orgs (grupo empresarial). '
    'Una org puede tener múltiples direcciones.';

CREATE INDEX IF NOT EXISTS idx_org_tiene_dir_org
    ON core.organizacion_tiene_direccion (organizacion_id)
    WHERE activo = true;

-- Migrar datos existentes (si los hay) al modelo relacional
-- antes de quitar organizacion_id de la tabla hija.
INSERT INTO core.organizacion_tiene_direccion
    (organizacion_id, direccion_id, tipo_direccion_id, es_principal, activo)
SELECT
    od.organizacion_id,
    od.organizacion_direccion_id,
    od.tipo_direccion_id,
    od.es_principal,
    od.activo
FROM core.organizacion_direccion od
WHERE od.organizacion_id IS NOT NULL
ON CONFLICT (organizacion_id, direccion_id) DO NOTHING;

-- ============================================================================
-- PARTE 4: Adaptar organizacion_direccion
-- - Reemplazar division_id (región) con comuna_id (nivel más específico)
-- - Quitar columnas que pasan a la tabla relacional (idempotente)
-- ============================================================================

-- 4a. Reemplazar division_id (nivel=1) por comuna_id (nivel=3).
--     Se mantiene pais CHAR(2) como respaldo legible cuando no hay FK.
--     Se mantiene ciudad VARCHAR como texto libre (p.ej. "sector Los Dominicos").
ALTER TABLE core.organizacion_direccion
    DROP COLUMN IF EXISTS division_id cascade,       -- reemplazado por comuna_id
    ADD  COLUMN IF NOT EXISTS comuna_id BIGINT
         REFERENCES core.division_admin(division_id) ON DELETE SET NULL;

COMMENT ON COLUMN core.organizacion_direccion.comuna_id IS
    'FK a division_admin (nivel=3=Comuna). '
    'Provincia y región se derivan por parent_division_id. '
    'Nulo cuando el país no tiene catálogo cargado (usar campo pais + ciudad).';

CREATE INDEX IF NOT EXISTS idx_org_dir_comuna
    ON core.organizacion_direccion (comuna_id)
    WHERE comuna_id IS NOT NULL;

-- 4b. Quitar columnas que migran a la tabla relacional.
--     Se usa bloque DO para idempotencia (no fallar si ya se quitaron).
DO $$
BEGIN
    -- organizacion_id → organizacion_tiene_direccion
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'core'
          AND table_name   = 'organizacion_direccion'
          AND column_name  = 'organizacion_id'
    ) THEN
        ALTER TABLE core.organizacion_direccion
            DROP COLUMN organizacion_id cascade;
    END IF;

    -- tipo_direccion_id → organizacion_tiene_direccion
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'core'
          AND table_name   = 'organizacion_direccion'
          AND column_name  = 'tipo_direccion_id'
    ) THEN
        ALTER TABLE core.organizacion_direccion
            DROP COLUMN tipo_direccion_id cascade;
    END IF;

    -- es_principal → organizacion_tiene_direccion
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'core'
          AND table_name   = 'organizacion_direccion'
          AND column_name  = 'es_principal'
    ) THEN
        ALTER TABLE core.organizacion_direccion
            DROP COLUMN es_principal cascade;
    END IF;

    -- region (texto) → derivado de comuna_id → prov → region
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'core'
          AND table_name   = 'organizacion_direccion'
          AND column_name  = 'region'
    ) THEN
        ALTER TABLE core.organizacion_direccion
            DROP COLUMN region cascade;
    END IF;

    -- comuna (texto) → reemplazada por FK comuna_id
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'core'
          AND table_name   = 'organizacion_direccion'
          AND column_name  = 'comuna'
    ) THEN
        ALTER TABLE core.organizacion_direccion
            DROP COLUMN comuna cascade;
    END IF;
END $$;

-- ============================================================================
-- PARTE 5: Actualizar trigger de sincronización de zonas
-- El trigger original (script 12) usaba organizacion_id + division_id (región).
-- Ahora: busca la región subiendo por la jerarquía desde comuna_id,
--        y busca la org(s) propietaria(s) desde la tabla relacional.
-- ============================================================================

CREATE OR REPLACE FUNCTION core.sync_zona_desde_direccion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_region_id BIGINT;
    v_org_id    BIGINT;
BEGIN
    IF NEW.comuna_id IS NULL THEN RETURN NEW; END IF;

    -- Subir jerarquía: comuna (nivel=3) → provincia (nivel=2) → región (nivel=1)
    SELECT prov.parent_division_id INTO v_region_id
    FROM core.division_admin com
    JOIN core.division_admin prov ON prov.division_id = com.parent_division_id
    WHERE com.division_id = NEW.comuna_id
      AND com.nivel  = 3
      AND prov.nivel = 2;

    IF v_region_id IS NULL THEN RETURN NEW; END IF;

    -- Upsert zona para cada organización que tenga esta dirección
    FOR v_org_id IN
        SELECT organizacion_id
        FROM core.organizacion_tiene_direccion
        WHERE direccion_id = NEW.organizacion_direccion_id
          AND activo = true
    LOOP
        INSERT INTO core.organizacion_zona_operacion
            (organizacion_id, division_id, es_principal, origen, direccion_origen_id)
        VALUES
            (v_org_id, v_region_id, false, 'DERIVADA_DIRECCION',
             NEW.organizacion_direccion_id)
        ON CONFLICT (organizacion_id, division_id) DO UPDATE SET
            direccion_origen_id = CASE
                WHEN core.organizacion_zona_operacion.origen = 'DECLARADA'
                    THEN core.organizacion_zona_operacion.direccion_origen_id
                ELSE EXCLUDED.direccion_origen_id
            END;
    END LOOP;

    RETURN NEW;
END;
$$;

-- Reemplaza el trigger del script 12 (mismo nombre, nueva lógica)
DROP TRIGGER IF EXISTS trg_sync_zona_desde_direccion ON core.organizacion_direccion;
CREATE OR REPLACE TRIGGER trg_sync_zona_desde_direccion
    AFTER INSERT OR UPDATE OF comuna_id
    ON core.organizacion_direccion
    FOR EACH ROW
    WHEN (NEW.comuna_id IS NOT NULL)
    EXECUTE FUNCTION core.sync_zona_desde_direccion();

-- ============================================================================
-- PARTE 6: Vistas de catálogo geográfico (usadas por el BFF)
--
-- Queries de los endpoints:
--   GET /api/geo/regiones?pais=CL
--     → SELECT * FROM core.v_geo_regiones WHERE pais_codigo = 'CL'
--
--   GET /api/geo/provincias?region={divisionId}
--     → SELECT * FROM core.v_geo_provincias WHERE region_id = $1
--
--   GET /api/geo/comunas?provincia={divisionId}
--     → SELECT * FROM core.v_geo_comunas WHERE provincia_id = $1
-- ============================================================================

CREATE OR REPLACE VIEW core.v_geo_regiones AS
SELECT
    da.division_id  AS id,
    da.codigo,
    da.nombre,
    da.nivel_nombre AS tipo,
    p.codigo        AS pais_codigo,
    p.nombre        AS pais_nombre
FROM core.division_admin da
JOIN core.pais p ON p.pais_id = da.pais_id
WHERE da.nivel = 1 AND da.activo = true
ORDER BY p.codigo, da.nombre;

CREATE OR REPLACE VIEW core.v_geo_provincias AS
SELECT
    da.division_id          AS id,
    da.codigo,
    da.nombre,
    da.nivel_nombre         AS tipo,
    da.parent_division_id   AS region_id,
    reg.nombre              AS region_nombre,
    p.codigo                AS pais_codigo
FROM core.division_admin da
JOIN core.division_admin reg ON reg.division_id = da.parent_division_id
JOIN core.pais p ON p.pais_id = da.pais_id
WHERE da.nivel = 2 AND da.activo = true
ORDER BY da.nombre;

CREATE OR REPLACE VIEW core.v_geo_comunas AS
SELECT
    da.division_id          AS id,
    da.codigo,
    da.nombre,
    da.nivel_nombre         AS tipo,
    da.parent_division_id   AS provincia_id,
    prov.nombre             AS provincia_nombre,
    reg.division_id         AS region_id,
    reg.nombre              AS region_nombre,
    p.codigo                AS pais_codigo
FROM core.division_admin da
JOIN core.division_admin prov ON prov.division_id = da.parent_division_id
JOIN core.division_admin reg  ON reg.division_id  = prov.parent_division_id
JOIN core.pais p ON p.pais_id = da.pais_id
WHERE da.nivel = 3 AND da.activo = true
ORDER BY da.nombre;

-- Vista de dirección completa con jerarquía derivada (útil para el BFF)
CREATE OR REPLACE VIEW core.v_organizacion_direccion_completa AS
SELECT
    od.organizacion_direccion_id,
    od.calle,
    od.numero,
    od.depto_oficina,
    od.ciudad,
    od.codigo_postal,
    od.pais             AS pais_fallback,
    od.referencia,
    od.activo,
    od.created_at,
    od.updated_at,
    -- Geo normalizado (derivado de FK)
    com.division_id     AS comuna_id,
    com.codigo          AS comuna_codigo,
    com.nombre          AS comuna_nombre,
    prov.division_id    AS provincia_id,
    prov.codigo         AS provincia_codigo,
    prov.nombre         AS provincia_nombre,
    reg.division_id     AS region_id,
    reg.codigo          AS region_codigo,
    reg.nombre          AS region_nombre,
    p.codigo            AS pais_codigo,
    p.nombre            AS pais_nombre
FROM core.organizacion_direccion od
LEFT JOIN core.division_admin com  ON com.division_id  = od.comuna_id    AND com.nivel  = 3
LEFT JOIN core.division_admin prov ON prov.division_id = com.parent_division_id  AND prov.nivel = 2
LEFT JOIN core.division_admin reg  ON reg.division_id  = prov.parent_division_id AND reg.nivel  = 1
LEFT JOIN core.pais p              ON p.pais_id        = reg.pais_id;

-- ============================================================================
-- PARTE 7: Catálogo de bancos (requerido por el wizard — step3Cedente)
-- ============================================================================

CREATE TABLE IF NOT EXISTS core.banco (
    banco_id   BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    codigo     VARCHAR(20)  UNIQUE NOT NULL,
    nombre     VARCHAR(120) NOT NULL,
    pais_id    INT REFERENCES core.pais(pais_id),
    activo     BOOLEAN NOT NULL DEFAULT true
);

-- Bancos de Chile (principales)
INSERT INTO core.banco (codigo, nombre, pais_id)
SELECT b.codigo, b.nombre, p.pais_id
FROM core.pais p,
(VALUES
    ('BANCHILE',    'Banco de Chile'),
    ('SANTANDER',   'Banco Santander Chile'),
    ('BCI',         'Banco BCI'),
    ('ESTADO',      'BancoEstado'),
    ('BBVA',        'BBVA Chile'),
    ('ITAU',        'Banco Itaú Chile'),
    ('SECURITY',    'Banco Security'),
    ('SCOTIABANK',  'Scotiabank Chile'),
    ('FALABELLA',   'Banco Falabella'),
    ('RIPLEY',      'Banco Ripley'),
    ('CONSORCIO',   'Banco Consorcio'),
    ('COOPEUCH',    'Coopeuch (Cooperativa)'),
    ('INTERNACIONAL','Banco Internacional'),
    ('BICE',        'BICE'),
    ('HSBC',        'HSBC Chile')
) AS b(codigo, nombre)
WHERE p.codigo = 'CL'
ON CONFLICT (codigo) DO NOTHING;

-- Endpoint: GET /api/bancos?pais=CL
-- Query:    SELECT banco_id AS id, nombre FROM core.banco
--           WHERE pais_id = (SELECT pais_id FROM core.pais WHERE codigo = $1)
--           AND activo = true ORDER BY nombre

-- ============================================================================
-- FIN 16_init_geo_normalizado.sql
-- ============================================================================
