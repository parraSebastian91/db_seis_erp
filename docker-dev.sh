#!/bin/bash

echo "🚀 Iniciando servicios en modo desarrollo..."

# Crear red si no existe
docker network create core_erp_network 2>/dev/null || true

# Levantar todos los servicios
docker-compose up -d

echo "⏳ Esperando que los servicios estén listos..."

# Esperar a que PostgreSQL esté listo
echo "📊 Esperando PostgreSQL..."
until docker exec core_erp_postgres pg_isready -U desarrollo -d core_erp; do
  echo "PostgreSQL no está listo, esperando..."
  sleep 2
done

# Esperar a que Redis esté listo
echo "📡 Esperando Redis..."
until docker exec core_erp_redis redis-cli ping; do
  echo "Redis no está listo, esperando..."
  sleep 2
done

echo "✅ Todos los servicios están funcionando"
echo ""
echo "🌐 Servicios disponibles:"
echo "  - PostgreSQL: localhost:5432"
echo "  - Redis: localhost:6379"
echo ""
echo "📋 Para ver los logs: docker-compose logs -f"
echo "🛑 Para detener: docker-compose down"
