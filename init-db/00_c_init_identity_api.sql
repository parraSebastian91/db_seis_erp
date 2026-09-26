-- =============================================================================
-- 00_c_init_identity_api.sql
-- RLS de identity + contrato de lectura para otros servicios (schema identity_api)
--
-- Gobierna: ms-identity.
-- Regla: los demás servicios (ms-core, ...) leen SOLO identity_api, nunca las
-- tablas base de identity. Las vistas son el contrato; se versionan aquí y en
-- las migraciones de ms-identity. Un cambio incompatible crea vistas v2_* y
-- deja las v_* vigentes hasta migrar a los consumidores.
--
-- Nunca se exponen: password_hash, sesiones/tokens, ni datos personales de
-- contacto más allá del nombre visible y el correo (ver
-- 00_auditoria_datos_personales.sql).
-- =============================================================================

SET search_path TO public, identity;

-- -----------------------------------------------------------------------------
-- 1. Helper de sesión + RLS de identity.contacto (antes en 14_init_rls.sql)
--    El servicio setea `SET LOCAL app.user_uuid = '<uuid>'` por transacción.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION identity.current_user_uuid()
RETURNS UUID LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN current_setting('app.user_uuid', true)::UUID;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$$;

ALTER TABLE identity.contacto ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.contacto FORCE ROW LEVEL SECURITY;

-- SELECT / UPDATE / DELETE: solo tu propio contacto
DROP POLICY IF EXISTS pol_contacto_owner ON identity.contacto;
CREATE POLICY pol_contacto_owner ON identity.contacto
    FOR ALL
    USING (
        contacto_id IN (
            SELECT u.contacto_id
            FROM identity.usuario u
            WHERE u.usuario_uuid = identity.current_user_uuid()
        )
        -- O el contexto no está seteado (migraciones / seeds sin SET LOCAL)
        OR identity.current_user_uuid() IS NULL
    );

-- Las vistas de identity_api las ejecuta su dueño (identity_api_owner) y NO
-- dependen de la sesión del consumidor: sin esta política, un consumidor que
-- haya hecho SET LOCAL app.user_uuid solo vería su propio contacto en las vistas.
-- ⚠️ Esta política aplica a identity_api_owner y a todo rol que HEREDE de él:
-- ningún rol de aplicación debe ser miembro con herencia de identity_api_owner
-- (00_a lo concede con INHERIT FALSE), o perdería la RLS de contacto.
DROP POLICY IF EXISTS pol_contacto_api_owner ON identity.contacto;
CREATE POLICY pol_contacto_api_owner ON identity.contacto
    FOR SELECT
    TO identity_api_owner
    USING (true);

-- -----------------------------------------------------------------------------
-- 2. Privilegios mínimos del dueño de las vistas (a nivel de columna)
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA identity TO identity_api_owner;
GRANT USAGE, CREATE ON SCHEMA identity_api TO identity_api_owner;

GRANT SELECT (contacto_id, nombres, apellido_paterno, apellido_materno, correo)
    ON identity.contacto TO identity_api_owner;
GRANT SELECT (usuario_id, usuario_uuid, username, activo, contacto_id, email_verificado)
    ON identity.usuario TO identity_api_owner;          -- sin password_hash
GRANT SELECT ON identity.usuario_rol, identity.rol, identity.rol_modulo_permiso,
                identity.modulo, identity.sistema, identity.funcionalidad,
                identity.permiso
    TO identity_api_owner;

-- -----------------------------------------------------------------------------
-- 3. Vistas de contrato v1 (creadas como identity_api_owner)
-- -----------------------------------------------------------------------------
SET ROLE identity_api_owner;

-- Usuario + nombre visible. Para buscar por uuid o username y mostrar nombres.
CREATE OR REPLACE VIEW identity_api.v_usuario AS
SELECT u.usuario_uuid,
       u.username,
       u.activo,
       u.email_verificado,
       c.nombres,
       c.apellido_paterno,
       c.apellido_materno,
       c.correo
FROM identity.usuario u
JOIN identity.contacto c ON c.contacto_id = u.contacto_id;

-- Roles por usuario.
CREATE OR REPLACE VIEW identity_api.v_usuario_rol AS
SELECT u.usuario_uuid,
       r.codigo AS rol_codigo,
       r.nombre AS rol_nombre
FROM identity.usuario u
JOIN identity.usuario_rol ur ON ur.usuario_id = u.usuario_id
JOIN identity.rol r          ON r.rol_id = ur.rol_id;

-- Navegación y permisos efectivos por usuario (sistema > módulo > funcionalidad
-- + permiso). El consumidor filtra por los sistemas contratados de la
-- organización uniendo con sistema_id (ej. core.organizacion_sistema).
CREATE OR REPLACE VIEW identity_api.v_usuario_navegacion AS
SELECT u.usuario_uuid,
       s.sistema_id,
       s.nombre       AS sistema_nombre,
       s.path         AS sistema_path,
       s.descripcion  AS sistema_descripcion,
       s.icono        AS sistema_icono,
       m.modulo_id,
       m.nombre       AS modulo_nombre,
       m.path         AS modulo_path,
       m.descripcion  AS modulo_descripcion,
       m.icono        AS modulo_icono,
       f.nombre       AS funcion_nombre,
       f.path         AS funcion_path,
       f.descripcion  AS funcion_descripcion,
       f.icono        AS funcion_icono,
       p.per_cod      AS permiso_codigo,
       p.per_nombre   AS permiso_nombre
FROM identity.usuario u
JOIN identity.usuario_rol ur         ON ur.usuario_id = u.usuario_id
JOIN identity.rol_modulo_permiso rmp ON rmp.rol_id = ur.rol_id
JOIN identity.modulo m               ON m.modulo_id = rmp.modulo_id AND m.activo = true
JOIN identity.sistema s              ON s.sistema_id = m.sistema_id AND s.activo = true
LEFT JOIN identity.funcionalidad f   ON f.modulo_id = m.modulo_id AND f.activo = true
JOIN identity.permiso p              ON p.permiso_id = rmp.permiso_id AND p.per_activo = true;

COMMENT ON VIEW identity_api.v_usuario IS 'Contrato identity_api v1. Usuario + nombre visible + correo.';
COMMENT ON VIEW identity_api.v_usuario_rol IS 'Contrato identity_api v1. Roles por usuario.';
COMMENT ON VIEW identity_api.v_usuario_navegacion IS 'Contrato identity_api v1. Navegación y permisos efectivos por usuario.';

GRANT SELECT ON identity_api.v_usuario, identity_api.v_usuario_rol, identity_api.v_usuario_navegacion
    TO identity_api_reader;

RESET ROLE;
