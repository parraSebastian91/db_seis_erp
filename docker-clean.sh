#!/bin/bash

echo "🧹 Limpiando recursos Docker..."

# Detener y eliminar contenedores
echo "🛑 Deteniendo contenedores..."
docker-compose down
docker-compose -f docker-compose.prod.yml down 2>/dev/null

# Eliminar imágenes relacionadas con ms-auth
echo "🗑️  Eliminando imágenes..."
docker images | grep ms-auth | awk '{print $3}' | xargs -r docker rmi -f

# Eliminar volúmenes no utilizados (opcional - descomenta si quieres eliminar datos)
# echo "💽 Eliminando volúmenes no utilizados..."
# docker volume prune -f

# Eliminar redes no utilizadas
echo "🌐 Limpiando redes no utilizadas..."
docker network prune -f

# Limpiar contenedores detenidos
echo "📦 Eliminando contenedores detenidos..."
docker container prune -f

# Limpiar cache de build
echo "🏗️  Limpiando cache de build..."
docker builder prune -f

echo "✅ Limpieza completada"

# Mostrar espacio recuperado
echo ""
echo "📊 Estado actual de Docker:"
docker system df
