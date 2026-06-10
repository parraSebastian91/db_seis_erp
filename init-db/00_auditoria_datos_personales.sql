-- =============================================================================
-- AUDITORÍA DE DATOS PERSONALES — SEIS APP
-- Ley 21.719 (Chile) / GDPR-compatible
-- Fecha: 2026-06-08
-- =============================================================================
-- Este archivo es SOLO documentación/referencia. No ejecutar en producción.
-- =============================================================================


-- =============================================================================
-- SECCIÓN A — INVENTARIO DE DATOS PERSONALES POR TABLA
-- =============================================================================
--
-- CLASIFICACIÓN DE RIESGO:
--   🔴 CRÍTICO  — Dato sensible / identificador único de persona natural
--   🟠 ALTO     — Dato personal que permite localizar o contactar a la persona
--   🟡 MEDIO    — Dato de comportamiento o relación comercial
--   🟢 BAJO     — Dato de contexto sin identidad directa
--
-- =============================================================================

/*
┌─────────────────────────────────────────────────────────────────────────────┐
│ SCHEMA: core                                                                │
└─────────────────────────────────────────────────────────────────────────────┘

TABLE: core.contacto
  🔴 nombres, apellido_paterno, apellido_materno   → Nombre completo persona natural
  🔴 tipo_documento + numero_documento             → RUT / DNI / Pasaporte (identificador único)
  🔴 fecha_nacimiento                              → Dato sensible (perfil etario)
  🟠 correo                                        → Canal de comunicación personal
  🟠 celular                                       → Canal de comunicación personal
  🟠 direccion (TEXT libre)                        → Domicilio (pre-normalización)
  🟡 redes_sociales JSONB                          → Perfiles en redes (dato de comportamiento)
  🟢 pais_emision, tipo_contacto_id                → Contexto, bajo riesgo

TABLE: core.usuario
  🔴 username                                      → Puede ser RUT o correo real
  🔴 password_hash                                 → Credencial (aunque hasheada)
  🟡 contacto_id → core.contacto                  → Indirecto, por FK

TABLE: core.organizacion
  🔴 rut + dv (tipo PERSONA_NATURAL)               → Identificador persona natural dueña
  🟠 razon_social (tipo PERSONA_NATURAL)           → Nombre real
  🟢 rut + dv (tipo JURIDICA)                      → Identificador empresa, no persona
  🟢 giro, tipo_organizacion, tipo_participante    → Dato empresarial

TABLE: core.organizacion_direccion
  🟠 calle, numero, depto, comuna, ciudad, region  → Dirección física (localización)
  🟢 tipo_direccion, codigo_postal, pais           → Contexto

TABLE: core.cuenta_bancaria
  🔴 rut_titular                                   → Identificador persona natural
  🟠 nombre_titular                                → Nombre real
  🟠 numero (cuenta bancaria)                      → Dato financiero sensible
  🟠 correo_contacto                               → Canal de contacto
  🟢 banco                                         → Contexto

TABLE: core.auth_refresh_sessions
  🟠 ip                                            → Dirección IP (dato personal en GDPR)
  🟠 user_agent                                    → Huella digital del dispositivo
  🟠 device_fingerprint                            → Huella del dispositivo
  🟡 refresh_token_hash                            → Credencial hasheada

TABLE: core.password_reset_tokens
  🟠 email                                         → Dato de contacto
  🟠 ip_address                                    → Dirección IP
  🟠 user_agent                                    → Huella digital

TABLE: core.organizacion_perfil (nueva)
  🟠 email_operaciones, telefono_operaciones       → Canal de contacto organizacional
  🟡 monto_min_usd, monto_max_usd                  → Capacidad financiera (dato comercial sensible)

TABLE: core.organizacion_credencial_sii (nueva)
  🔴 clave_sii_enc / vault_secret_path             → Credencial de acceso a sistema tributario
  🔴 rut_empresa (PERSONA_NATURAL)                 → Identificador persona natural

┌─────────────────────────────────────────────────────────────────────────────┐
│ SCHEMA: factura                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

TABLE: factura.factura
  🔴 deudor_rut                                    → RUT persona natural o empresa (contribuyente)
  🟠 deudor_nombre                                 → Nombre del deudor (puede ser persona natural)
  🟡 monto_total, fecha_vencimiento                → Dato financiero / comercial
  🟢 factura_numero, status, created_by            → Dato operacional

TABLE: factura.historial_negocios
  🟡 calificacion_a_organizacion                  → Calificación (dato de reputación)
  🟡 calificacion_a_usuario                       → Calificación a persona (dato de reputación)
  🟡 comentarios_empresa, comentarios_ejecutiva   → Texto libre (puede contener datos personales)
  🟡 monto_final_operado                          → Dato financiero

TABLE: factura.autorizacion_publicacion
  🟠 ip_address                                   → Dirección IP (dato personal GDPR)
  🟠 user_agent                                   → Huella digital
  🟡 acepto (consentimiento)                      → Registro de voluntad

TABLE: factura.control_cambios
  🟡 metadata JSONB                               → Puede contener cualquier dato del dominio
  🟡 valor_anterior, valor_nuevo (TEXT)           → Puede exponer datos personales en histórico

TABLE: factura.notas_ocr
  🟡 valor_declarado, valor_ocr                   → Puede contener RUT/nombre del deudor

┌─────────────────────────────────────────────────────────────────────────────┐
│ SCHEMA: social                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

TABLE: social.comentario_post
  🟡 contenido TEXT                               → Texto libre (puede mencionar personas)

TABLE: social.calificacion_trabajo
  🟡 comentario_publico TEXT                      → Texto libre con datos de reputación

┌─────────────────────────────────────────────────────────────────────────────┐
│ SCHEMA: media                                                               │
└─────────────────────────────────────────────────────────────────────────────┘

TABLE: media.media_assets
  🟠 original_name                                → Nombre original del archivo (puede ser RUT.pdf)
  🟠 storage_key                                  → Path en MinIO (puede codificar identidad)
  🟡 owner_id UUID                                → Asociado a un usuario

*/


-- =============================================================================
-- SECCIÓN B — RESUMEN DE RIESGO CONSOLIDADO
-- =============================================================================

/*
DATOS MÁS CRÍTICOS (acción inmediata):
  1. core.contacto.numero_documento (RUT/DNI/Pasaporte) — identificador único personal
  2. core.cuenta_bancaria.numero + rut_titular        — dato bancario + identificador
  3. factura.factura.deudor_rut                        — RUT sin enmascarar en tabla principal
  4. core.organizacion_credencial_sii                  — credencial de sistema tributario
  5. factura.control_cambios.metadata JSONB            — histórico sin control, acumula todo

DATOS DE RIESGO MEDIO (revisión):
  6. core.auth_refresh_sessions.ip + device_fingerprint
  7. core.contacto.redes_sociales JSONB               — perfiles de terceras plataformas
  8. factura.historial_negocios.comentarios_*         — texto libre sin moderación
  9. media.media_assets.original_name                 — puede exponer identidad en nombre de archivo

DATO POSITIVO — YA BIEN IMPLEMENTADO:
  ✅ core.usuario.password_hash                       — hash, no texto plano
  ✅ core.organizacion_credencial_sii.clave_sii_enc   — cifrado + Vault
  ✅ factura.autorizacion_publicacion                 — registro de consentimiento inmutable
  ✅ factura.version_terminos.hash_sha256             — prueba de integridad del texto
*/


-- =============================================================================
-- SECCIÓN C — PLAN DE RESGUARDO POR NIVEL
-- =============================================================================

/*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NIVEL 1 — BASE DE DATOS (PostgreSQL)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1a. ENMASCARAMIENTO en columnas de alto riesgo (leer desde aplicación)
    Implementar en la capa de VISTA, no en la tabla base:

    -- Ejemplo: RUT del deudor enmascarado para roles no autorizados
    CREATE OR REPLACE VIEW factura.vw_factura_publica AS
    SELECT
        id,
        deudor_nombre,
        overlay(deudor_rut placing '****' from 1 for 4) AS deudor_rut_enmascarado,
        monto_total,
        fecha_vencimiento,
        status
    FROM factura.factura;

    -- Ejemplo: cuenta bancaria enmascarada
    CREATE OR REPLACE VIEW core.vw_cuenta_bancaria_segura AS
    SELECT
        cuenta_id,
        organizacion_id,
        nombre_titular,
        overlay(rut_titular placing '**-*' from 5) AS rut_titular_enmascarado,
        banco,
        overlay(numero placing repeat('*', length(numero)-4) from 1 for length(numero)-4) AS numero_enmascarado
    FROM core.cuenta_bancaria;

1b. ROW LEVEL SECURITY (RLS) — Solo el dueño o rol autorizado ve sus datos
    ALTER TABLE core.contacto ENABLE ROW LEVEL SECURITY;
    ALTER TABLE core.cuenta_bancaria ENABLE ROW LEVEL SECURITY;
    ALTER TABLE factura.factura ENABLE ROW LEVEL SECURITY;

    -- Política: usuario solo ve su propio contacto
    CREATE POLICY pol_contacto_owner ON core.contacto
        FOR ALL
        USING (contacto_id IN (
            SELECT contacto_id FROM core.usuario
            WHERE usuario_uuid = current_setting('app.user_uuid')::UUID
        ));

1c. CIFRADO en columnas críticas (pgcrypto, ya instalado)
    -- Número de cuenta bancaria: cifrar con clave de aplicación
    ALTER TABLE core.cuenta_bancaria
        ADD COLUMN numero_enc BYTEA;
    -- La aplicación cifra con: pgp_sym_encrypt(numero, APP_BANK_ENC_KEY)
    -- y deja numero original para migración, luego lo elimina.

1d. RETENCIÓN Y BORRADO AUTOMÁTICO
    -- Eliminar sesiones expiradas (job nocturno o pg_cron)
    DELETE FROM core.auth_refresh_sessions WHERE expires_at < now() - interval '7 days';
    DELETE FROM core.password_reset_tokens WHERE expires_at < now() - interval '1 day';

    -- Pseudoanonimizar contactos eliminados (soft delete ya existe via eliminado_at)
    -- Al activar eliminado_at, reemplazar datos personales por tokens anónimos:
    UPDATE core.contacto SET
        nombres = 'Usuario',
        apellido_paterno = 'Eliminado',
        apellido_materno = NULL,
        celular = NULL,
        correo = 'eliminado_' || contacto_id || '@anonimo.local',
        numero_documento = NULL,
        fecha_nacimiento = NULL,
        redes_sociales = '{}'
    WHERE eliminado_at IS NOT NULL;

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NIVEL 2 — APLICACIÓN (NestJS)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2a. DTOs con exclusión de campos sensibles (@Exclude, class-transformer)
    - Nunca exponer: password_hash, device_fingerprint, ip en respuestas de API
    - El BFF filtra antes de enviar al frontend

2b. Inyección de app.user_uuid en SET LOCAL para RLS y auditoría
    -- En cada transacción NestJS:
    await queryRunner.query(`SET LOCAL app.user_uuid = '${userUuid}'`);

2c. Rate limiting en endpoints de datos personales
    - POST /registro, POST /auth/reset-password: máximo 5 req/min por IP

2d. Validación de RUT en entrada (evitar almacenar RUT inválidos)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NIVEL 3 — INFRAESTRUCTURA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

3a. MinIO /private → TLS obligatorio + presigned URLs con TTL corto (15 min)
    - Facturas nunca en /public (ya implementado según CLAUDE.md)

3b. PostgreSQL → SSL en tránsito (sslmode=require en conexiones de servicios)

3c. Vault → Rotación de secretos cada 90 días (clave SII, JWT_SECRET)

3d. Backups cifrados → pgBackRest o pg_dump | gpg -e -r PUBKEY

3e. Logs de aplicación → NO loggear datos personales en texto plano
    - Usar correlation_id en vez de RUT/nombre en logs

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NIVEL 4 — CUMPLIMIENTO (Ley 21.719 Chile)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

4a. DERECHO DE ACCESO → endpoint GET /api/core/usuario/mis-datos
    Retorna todos los datos personales del usuario autenticado

4b. DERECHO AL OLVIDO → endpoint DELETE /api/core/usuario
    Desencadena pseudoanonimización (punto 1d arriba)
    Conserva historial financiero anonimizado (obligación contable 5 años)

4c. PORTABILIDAD → endpoint GET /api/core/usuario/exportar
    Formato JSON/CSV con todos los datos del usuario

4d. CONSENTIMIENTO INFORMADO → ya implementado en factura.autorizacion_publicacion
    Extender para: registro de usuario, marketing, procesamiento OCR

4e. REGISTRO DE ACTIVIDADES DE TRATAMIENTO (RAT) — documento legal
    Mapear: qué datos, para qué fin, base legal, plazo de retención, transferencias

*/


-- =============================================================================
-- SECCIÓN D — ACCIONES PRIORITARIAS (ORDENADAS POR URGENCIA)
-- =============================================================================

/*
PRIORIDAD 1 — ANTES DE PRODUCCIÓN (bloqueante)
  [ ] Activar RLS en core.contacto, core.cuenta_bancaria, factura.factura
  [ ] Enmascarar deudor_rut en vistas expuestas al frontend
  [ ] Cifrar numero en core.cuenta_bancaria (número de cuenta bancaria)
  [ ] Implementar pseudoanonimización al activar eliminado_at en contacto
  [ ] Agregar pg_cron para limpiar sesiones/tokens expirados

PRIORIDAD 2 — PRIMER MES EN PRODUCCIÓN
  [ ] Endpoints ARCO (Acceso, Rectificación, Cancelación, Oposición)
  [ ] Auditar original_name en media.media_assets (limpiar o cifrar)
  [ ] Revisar que factura.control_cambios no exponga RUT en metadata JSONB
  [ ] Política de retención: definir plazos por tipo de dato

PRIORIDAD 3 — TRIMESTRE
  [ ] Certificar SSL en todas las conexiones DB → servicios
  [ ] Rotación automática de secretos en Vault (cada 90 días)
  [ ] Backups cifrados con GPG
  [ ] Redactar RAT (Registro de Actividades de Tratamiento)
  [ ] Nombrar Encargado de Protección de Datos (EPD) si aplica por tamaño
*/

-- =============================================================================
-- FIN AUDITORÍA — SEIS APP — 2026-06-08
-- =============================================================================
