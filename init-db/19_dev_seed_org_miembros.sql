-- =============================================================================
-- 19_dev_seed_org_miembros.sql  (SOLO DESARROLLO)
-- Escenario de prueba (contraseña común de desarrollo: Usuario123.-)
--
--   Seis Spa (CEDENTE)               isepulveda = ADMIN de la organización
--                                    sparra     = COLABORADOR      -> grupo "Equipo Comercial"
--   Comercial Sur Limitada (CEDENTE) parrita    = ADMIN
--   Financiera Andina SpA (FINANC.)  crojas2    = ADMIN            -> grupo "Mesa de Inversión"
--   Capital Norte Factoring (FINANC.) psilva    = ADMIN
--
-- Roles globales (identity) alineados: los cedentes usan *_CEDENTE y las financiadoras
-- *_FINANCIADORA, que es lo que decide a qué portal entra cada usuario.
-- Idempotente. No corre en producción.
-- =============================================================================
DO $$
DECLARE
  v_isepulveda UUID; v_sparra UUID; v_crojas2 UUID; v_parrita UUID; v_psilva UUID;
  v_seis BIGINT; v_sur BIGINT; v_andina BIGINT; v_norte BIGINT;
  v_g_com UUID; v_g_inv UUID;
BEGIN
  SELECT usuario_uuid INTO v_isepulveda FROM identity.usuario WHERE username = 'isepulveda';
  SELECT usuario_uuid INTO v_sparra     FROM identity.usuario WHERE username = 'sparra';
  SELECT usuario_uuid INTO v_crojas2    FROM identity.usuario WHERE username = 'crojas2';
  SELECT usuario_uuid INTO v_parrita    FROM identity.usuario WHERE username = 'parrita';
  SELECT usuario_uuid INTO v_psilva     FROM identity.usuario WHERE username = 'psilva';
  IF v_isepulveda IS NULL OR v_sparra IS NULL OR v_crojas2 IS NULL OR v_parrita IS NULL OR v_psilva IS NULL THEN
    RAISE NOTICE 'Usuarios de prueba no encontrados; se omite el seed de membresías';
    RETURN;
  END IF;

  SELECT organizacion_id INTO v_seis   FROM core.organizacion WHERE razon_social = 'Seis Spa';
  SELECT organizacion_id INTO v_sur    FROM core.organizacion WHERE razon_social = 'Comercial Sur Limitada';
  SELECT organizacion_id INTO v_andina FROM core.organizacion WHERE razon_social = 'Financiera Andina SpA';
  SELECT organizacion_id INTO v_norte  FROM core.organizacion WHERE razon_social = 'Capital Norte Factoring Ltda';

  -- Escenario limpio para estos usuarios
  DELETE FROM core.organizacion_miembro
   WHERE usuario_uuid IN (v_isepulveda, v_sparra, v_crojas2, v_parrita, v_psilva);

  INSERT INTO core.organizacion_miembro (organizacion_id, usuario_uuid, rol_codigo, activo) VALUES
    (v_seis,   v_isepulveda, 'ADMIN',       true),
    (v_seis,   v_sparra,     'COLABORADOR', true),
    (v_sur,    v_parrita,    'ADMIN',       true),
    (v_andina, v_crojas2,    'ADMIN',       true),
    (v_norte,  v_psilva,     'ADMIN',       true)
  ON CONFLICT (organizacion_id, usuario_uuid) DO UPDATE SET rol_codigo = EXCLUDED.rol_codigo, activo = true;

  -- Sistemas contratados: además de Factoring, Organización (Miembros, Work Team, Solicitudes, + Organización)
  INSERT INTO core.organizacion_sistema (organizacion_id, sistema_id)
  SELECT o, s.sistema_id FROM unnest(ARRAY[v_seis, v_sur, v_andina, v_norte]) AS o, identity.sistema s
   WHERE s.nombre IN ('Factoring', 'Organización')
  ON CONFLICT DO NOTHING;

  -- Roles globales: financiadoras
  INSERT INTO identity.usuario_rol (usuario_id, rol_id)
  SELECT u.usuario_id, r.rol_id FROM identity.usuario u, identity.rol r
   WHERE (u.username, r.codigo) IN (('crojas2','EJECUTIVO_FINANCIADORA'), ('crojas2','ADMIN_FINANCIADORA'),
                                    ('psilva','ADMIN_FINANCIADORA'), ('parrita','ADMIN_CEDENTE'))
  ON CONFLICT DO NOTHING;
  DELETE FROM identity.usuario_rol ur USING identity.usuario u, identity.rol r
   WHERE ur.usuario_id = u.usuario_id AND ur.rol_id = r.rol_id
     AND u.username = 'psilva' AND r.codigo = 'CLIENTE_CEDENTE';

  -- Grupos de trabajo (core.grupo_trabajo.organizacion_id referencia organizacion_uuid)
  SELECT grupo_id INTO v_g_com FROM core.grupo_trabajo
   WHERE nombre = 'Equipo Comercial' AND organizacion_id = (SELECT organizacion_uuid FROM core.organizacion WHERE organizacion_id = v_seis);
  IF v_g_com IS NULL THEN
    INSERT INTO core.grupo_trabajo (nombre, descripcion, lider_usuario_uuid, organizacion_id)
    SELECT 'Equipo Comercial', 'Gestión de facturas y clientes de Seis Spa', v_isepulveda, organizacion_uuid
      FROM core.organizacion WHERE organizacion_id = v_seis
    RETURNING grupo_id INTO v_g_com;
  END IF;
  INSERT INTO core.grupo_miembro (grupo_id, usuario_uuid, cargo_en_grupo) VALUES
    (v_g_com, v_isepulveda, 'Lider de equipo'),
    (v_g_com, v_sparra,     'Analista')
  ON CONFLICT (grupo_id, usuario_uuid) DO NOTHING;

  SELECT grupo_id INTO v_g_inv FROM core.grupo_trabajo
   WHERE nombre = 'Mesa de Inversión' AND organizacion_id = (SELECT organizacion_uuid FROM core.organizacion WHERE organizacion_id = v_andina);
  IF v_g_inv IS NULL THEN
    INSERT INTO core.grupo_trabajo (nombre, descripcion, lider_usuario_uuid, organizacion_id)
    SELECT 'Mesa de Inversión', 'Evaluación y oferta de facturas', v_crojas2, organizacion_uuid
      FROM core.organizacion WHERE organizacion_id = v_andina
    RETURNING grupo_id INTO v_g_inv;
  END IF;
  INSERT INTO core.grupo_miembro (grupo_id, usuario_uuid, cargo_en_grupo)
  VALUES (v_g_inv, v_crojas2, 'Lider de equipo')
  ON CONFLICT (grupo_id, usuario_uuid) DO NOTHING;
END $$;
