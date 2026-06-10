-- =============================================================================
-- 15_init_email_verificacion.sql
-- Verificación de correo electrónico tras el registro
-- =============================================================================

SET search_path TO public, core;

-- 1. Flag en usuario (empieza en false, se activa al verificar)
ALTER TABLE core.usuario
    ADD COLUMN IF NOT EXISTS email_verificado BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS email_verificado_at TIMESTAMPTZ;

COMMENT ON COLUMN core.usuario.email_verificado IS
    'true cuando el usuario confirmó su correo con el código de 6 dígitos.';

-- =============================================================================
-- FIN 15_init_email_verificacion.sql
-- =============================================================================
