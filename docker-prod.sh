#!/bin/bash

echo "🏭 Iniciando servicios en modo producción..."

# Crear red si no existe
docker network create core_erp_network 2>/dev/null || true

# Levantar todos los servicios en modo producción
docker-compose -f docker-compose.prod.yml up -d

echo "⏳ Esperando que los servicios estén listos..."

# Esperar a que PostgreSQL esté listo
echo "📊 Esperando PostgreSQL..."
until docker exec core_erp_postgres_prod pg_isready -U desarrollo -d core_erp; do
  echo "PostgreSQL no está listo, esperando..."
  sleep 2
done

# Esperar a que Redis esté listo
echo "📡 Esperando Redis..."
until docker exec core_erp_redis_prod redis-cli ping; do
  echo "Redis no está listo, esperando..."
  sleep 2
done

echo "✅ Todos los servicios están funcionando en modo producción"
echo ""
echo "🌐 Servicios disponibles:"
echo "  - Aplicación NestJS: http://localhost:3000"
echo "  - PostgreSQL: localhost:5432"
echo "  - Redis: localhost:6379"
echo ""
echo "📋 Para ver los logs: docker-compose -f docker-compose.prod.yml logs -f"
echo "🛑 Para detener: docker-compose -f docker-compose.prod.yml down"
