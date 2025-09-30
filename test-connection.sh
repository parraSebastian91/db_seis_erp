#!/bin/bash

# Script para probar la conexión a los servicios dockerizados
# Uso: ./test-connection.sh

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_message $BLUE "🧪 Probando conexiones a los servicios..."
echo

# Probar PostgreSQL
print_message $BLUE "🗄️  Probando PostgreSQL..."
if docker-compose exec -T postgres psql -U desarrollo -d core_erp -c "SELECT version();" &> /dev/null; then
    print_message $GREEN "✅ PostgreSQL conectado exitosamente"
    
    # Verificar esquemas
    SCHEMAS=$(docker-compose exec -T postgres psql -U desarrollo -d core_erp -t -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('core', 'bodega');" | xargs)
    print_message $BLUE "   Esquemas encontrados: $SCHEMAS"
    
    # Verificar algunas tablas
    CORE_TABLES=$(docker-compose exec -T postgres psql -U desarrollo -d core_erp -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'core';" | xargs)
    BODEGA_TABLES=$(docker-compose exec -T postgres psql -U desarrollo -d core_erp -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'bodega';" | xargs)
    print_message $BLUE "   Tablas en esquema 'core': $CORE_TABLES"
    print_message $BLUE "   Tablas en esquema 'bodega': $BODEGA_TABLES"
    
else
    print_message $RED "❌ Error conectando a PostgreSQL"
fi

echo

# Probar Redis
print_message $BLUE "🔴 Probando Redis..."
if docker-compose exec -T redis redis-cli ping | grep -q "PONG"; then
    print_message $GREEN "✅ Redis conectado exitosamente"
    
    # Información de Redis
    INFO=$(docker-compose exec -T redis redis-cli info server | grep redis_version | cut -d: -f2 | tr -d '\r')
    print_message $BLUE "   Versión de Redis: $INFO"
    
    # Probar set/get
    docker-compose exec -T redis redis-cli set test_key "test_value" &> /dev/null
    TEST_VALUE=$(docker-compose exec -T redis redis-cli get test_key | tr -d '\r')
    if [ "$TEST_VALUE" = "test_value" ]; then
        print_message $GREEN "   ✅ Operaciones SET/GET funcionando"
        docker-compose exec -T redis redis-cli del test_key &> /dev/null
    else
        print_message $YELLOW "   ⚠️  Operaciones SET/GET tienen problemas"
    fi
else
    print_message $RED "❌ Error conectando a Redis"
fi

echo

# Probar interfaces web
print_message $BLUE "🌐 Probando interfaces web..."

# PgAdmin
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302"; then
    print_message $GREEN "✅ PgAdmin disponible en http://localhost:8080"
else
    print_message $YELLOW "⚠️  PgAdmin no responde en http://localhost:8080"
fi

# Redis Commander
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 | grep -q "200\|302"; then
    print_message $GREEN "✅ Redis Commander disponible en http://localhost:8081"
else
    print_message $YELLOW "⚠️  Redis Commander no responde en http://localhost:8081"
fi

echo
print_message $BLUE "🏁 Pruebas completadas"
