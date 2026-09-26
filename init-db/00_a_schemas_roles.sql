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
    -- Dueño de las vistas de identity_api (ver 00_c_init_identity_api.sql).
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'identity_api_owner') THEN
        CREATE ROLE identity_api_owner NOLOGIN;
    END IF;
END
$$;

-- Los consumidores de identidad leen SOLO identity_api, nunca identity.
GRANT USAGE ON SCHEMA identity_api TO identity_api_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA identity_api GRANT SELECT ON TABLES TO identity_api_reader;

-- Mientras los servicios compartan el usuario de conexión actual, ese usuario
-- pertenece a los grupos de datos (no se rompe nada). Al separar credenciales por
-- servicio, quitar estas membresías y asignar cada servicio a su grupo.
-- Tolerante: si el usuario de carga no es superusuario, las membresías se
-- asignan antes (ver proyectos-infra/scripts/load-seis-initdb.sh).
--
-- ⚠️ identity_api_owner SIN herencia (WITH INHERIT FALSE, SET TRUE): solo permite
-- SET ROLE para crear las vistas. Con herencia, el usuario de la app heredaría la
-- política pol_contacto_api_owner (USING true) y la RLS de identity.contacto
-- dejaría de aplicarle. Requiere PostgreSQL >= 16.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desarrollo') THEN
        IF NOT pg_has_role('desarrollo', 'identity_owner', 'MEMBER') THEN
            GRANT identity_owner, core_owner, identity_api_reader TO desarrollo;
        END IF;
        IF NOT pg_has_role('desarrollo', 'identity_api_owner', 'SET') THEN
            EXECUTE 'GRANT identity_api_owner TO desarrollo WITH INHERIT FALSE, SET TRUE';
        END IF;
    END IF;
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Sin privilegio para asignar membresías a desarrollo; asignarlas como superusuario';
END
$$;
