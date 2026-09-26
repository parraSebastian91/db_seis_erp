-- =============================================================================
-- 00_a_schemas_roles.sql
-- Esquemas por servicio + roles de grupo (sin login, sin secretos).
--
-- Gobierno de esquemas (refactor ms-identity):
--   identity     -> ms-identity (usuarios, contactos, roles, permisos, sistemas...)
--   identity_api -> ms-identity (vistas de solo lectura = contrato para otros servicios)
--   core         -> ms-core
--   media        -> ms-storage / ms-core
--   factura      -> ms-core
--
-- Orden de creación de tablas: identity -> core -> resto (core referencia identity).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS identity_api;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS media;
CREATE SCHEMA IF NOT EXISTS factura;

-- Roles de grupo (NOLOGIN). Los roles con login por servicio se crean fuera de
-- este script (credenciales en Vault) y se hacen miembros de estos grupos.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'identity_owner') THEN
        CREATE ROLE identity_owner NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'core_owner') THEN
        CREATE ROLE core_owner NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'identity_api_reader') THEN
        CREATE ROLE identity_api_reader NOLOGIN;
    END IF;
END
$$;

-- Los consumidores de identidad leen SOLO identity_api, nunca identity.
GRANT USAGE ON SCHEMA identity_api TO identity_api_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA identity_api GRANT SELECT ON TABLES TO identity_api_reader;

-- Mientras los servicios compartan el usuario de conexión actual, ese usuario
-- pertenece a todos los grupos (no se rompe nada). Al separar credenciales por
-- servicio, quitar estas membresías y asignar cada servicio a su grupo.
-- Tolerante: si el usuario de carga no es superusuario, las membresías se
-- asignan antes (ver proyectos-infra/scripts/load-seis-initdb.sh).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desarrollo')
       AND NOT pg_has_role('desarrollo', 'identity_owner', 'MEMBER') THEN
        GRANT identity_owner, core_owner, identity_api_reader TO desarrollo;
    END IF;
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Sin privilegio para asignar membresías a desarrollo; asignarlas como superusuario';
END
$$;
