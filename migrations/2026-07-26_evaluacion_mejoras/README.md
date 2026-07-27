# Migraciones de Mejora - Evaluación Base de Datos 2026-07-26

Este directorio contiene las migraciones propuestas tras la evaluación completa del esquema de base de datos.

**⚠️ NOTA:** Schema `bodega` está en stand-by y NO se incluye en estas migraciones.

## Prioridad de Ejecución

### 🔴 CRÍTICAS (ejecutar antes de producción)
1. `001_add_missing_indexes.sql` — Índices faltantes en FKs (20 min)
2. `002_fix_monto_total_decimal.sql` — Corregir tipo de dato VARCHAR → DECIMAL (2 horas)
3. `003_remove_duplicate_indexes.sql` — Eliminar índices duplicados (5 min)

### 🟠 IMPORTANTES (próximo sprint)
4. `004_add_partial_indexes_soft_deletes.sql` — Índices parciales (20 min)
5. `005_add_cleanup_guardrails.sql` — Guardrails de seguridad (10 min)

## Orden de Aplicación

```bash
# 1. CRÍTICAS (en orden)
psql -d seis_erp -f 001_add_missing_indexes.sql
psql -d seis_erp -f 002_fix_monto_total_decimal.sql
psql -d seis_erp -f 003_remove_duplicate_indexes.sql

# 2. IMPORTANTES (después de testing)
psql -d seis_erp -f 004_add_partial_indexes_soft_deletes.sql
psql -d seis_erp -f 005_add_cleanup_guardrails.sql
```

## Rollback

Cada script tiene su propio bloque de rollback al final. En caso de error:

```bash
# Ver últimas migraciones aplicadas
SELECT * FROM pg_stat_user_tables WHERE schemaname IN ('core', 'factura', 'permisos') ORDER BY last_vacuum DESC LIMIT 10;

# Rollback manual (ejemplo para 001)
DROP INDEX IF EXISTS idx_usuario_contacto_id;
DROP INDEX IF EXISTS idx_org_dir_organizacion_id;
-- ... (ver sección ROLLBACK en cada script)
```

## Verificación Post-Migración

```bash
# Verificar índices creados
psql -d seis_erp -c "
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE schemaname IN ('core', 'factura', 'permisos', 'media', 'bodega')
  AND indexname LIKE 'idx_%'
ORDER BY schemaname, tablename;
"

# Verificar tipo de monto_total
psql -d seis_erp -c "
SELECT column_name, data_type, character_maximum_length, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_schema = 'factura' AND table_name = 'factura' AND column_name LIKE 'monto_total%';
"
```

## Reporte de Evaluación

Ver documento completo:
`/home/seba/Hermes-Agent/knowledge_base/Proyectos/SEIS_APP/Database-Evaluation-Report-2026-07-26.md`
