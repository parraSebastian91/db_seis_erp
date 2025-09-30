#!/bin/bash

# Script para inicializar el entorno dockerizado del ERP
# Uso: ./start.sh [opciones]

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con color
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Función para verificar si Docker está instalado y funcionando
check_docker() {
    print_message $BLUE "🔍 Verificando Docker..."
    
    if ! command -v docker &> /dev/null; then
        print_message $RED "❌ Docker no está instalado. Por favor instala Docker primero."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_message $RED "❌ Docker no está funcionando. Asegúrate de que Docker Desktop esté ejecutándose."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_message $RED "❌ Docker Compose no está instalado."
        exit 1
    fi
    
    print_message $GREEN "✅ Docker y Docker Compose están disponibles"
}

# Función para verificar archivos de configuración
check_config() {
    print_message $BLUE "🔍 Verificando configuración..."
    
    if [ ! -f "docker-compose.yml" ]; then
        print_message $RED "❌ Archivo docker-compose.yml no encontrado"
        exit 1
    fi
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            print_message $YELLOW "⚠️  Archivo .env no encontrado, copiando desde .env.example"
            cp .env.example .env
        else
            print_message $YELLOW "⚠️  Usando configuración por defecto (no se encontró .env)"
        fi
    fi
    
    print_message $GREEN "✅ Configuración verificada"
}

# Función para verificar puertos disponibles
check_ports() {
    print_message $BLUE "🔍 Verificando puertos..."
    
    local ports=(5432 6379 8080 8081)
    local busy_ports=()
    
    for port in "${ports[@]}"; do
        if lsof -i:$port &> /dev/null; then
            busy_ports+=($port)
        fi
    done
    
    if [ ${#busy_ports[@]} -gt 0 ]; then
        print_message $YELLOW "⚠️  Los siguientes puertos están en uso: ${busy_ports[*]}"
        print_message $YELLOW "    Puedes cambiar los puertos en el archivo .env o docker-compose.yml"
        read -p "¿Continuar de todos modos? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_message $GREEN "✅ Puertos disponibles"
    fi
}

# Función para iniciar servicios
start_services() {
    local mode=$1
    
    print_message $BLUE "🚀 Iniciando servicios..."
    
    if [ "$mode" = "build" ]; then
        docker-compose up --build -d
    else
        docker-compose up -d
    fi
    
    print_message $GREEN "✅ Servicios iniciados"
}

# Función para verificar el estado de los servicios
check_services() {
    print_message $BLUE "🔍 Verificando estado de servicios..."
    
    # Esperar un poco para que los servicios se inicien
    sleep 5
    
    # Verificar PostgreSQL
    if docker-compose exec -T postgres pg_isready -U desarrollo -d core_erp &> /dev/null; then
        print_message $GREEN "✅ PostgreSQL está funcionando"
    else
        print_message $YELLOW "⚠️  PostgreSQL aún se está iniciando..."
    fi
    
    # Verificar Redis
    if docker-compose exec -T redis redis-cli ping &> /dev/null; then
        print_message $GREEN "✅ Redis está funcionando"
    else
        print_message $YELLOW "⚠️  Redis aún se está iniciando..."
    fi
    
    print_message $BLUE "📊 Estado de contenedores:"
    docker-compose ps
}

# Función para mostrar información de conexión
show_connection_info() {
    print_message $BLUE "📋 Información de conexión:"
    echo
    print_message $GREEN "🗄️  PostgreSQL:"
    echo "   Host: localhost"
    echo "   Puerto: 5432"
    echo "   Base de datos: core_erp"
    echo "   Usuario: desarrollo"
    echo "   Contraseña: desarrollo123"
    echo
    print_message $GREEN "🔴 Redis:"
    echo "   Host: localhost"
    echo "   Puerto: 6379"
    echo
    print_message $GREEN "🌐 Interfaces web:"
    echo "   PgAdmin: http://localhost:8080"
    echo "   Redis Commander: http://localhost:8081"
    echo
}

# Función para mostrar logs
show_logs() {
    print_message $BLUE "📋 Mostrando logs (Ctrl+C para salir):"
    docker-compose logs -f
}

# Función para parar servicios
stop_services() {
    print_message $BLUE "🛑 Parando servicios..."
    docker-compose stop
    print_message $GREEN "✅ Servicios parados"
}

# Función para limpiar todo
cleanup() {
    print_message $YELLOW "⚠️  Esto eliminará todos los contenedores y volúmenes (se perderán los datos)"
    read -p "¿Estás seguro? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_message $BLUE "🧹 Limpiando..."
        docker-compose down -v
        docker system prune -f
        print_message $GREEN "✅ Limpieza completada"
    fi
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [opción]"
    echo
    echo "Opciones:"
    echo "  start         Iniciar servicios (por defecto)"
    echo "  stop          Parar servicios"
    echo "  restart       Reiniciar servicios"
    echo "  status        Mostrar estado de servicios"
    echo "  logs          Mostrar logs"
    echo "  cleanup       Limpiar todo (elimina datos)"
    echo "  build         Construir e iniciar servicios"
    echo "  help          Mostrar esta ayuda"
    echo
}

# Función principal
main() {
    local command=${1:-start}
    
    print_message $BLUE "🐳 ERP Database Docker Manager"
    echo
    
    case $command in
        start)
            check_docker
            check_config
            check_ports
            start_services
            check_services
            show_connection_info
            ;;
        stop)
            stop_services
            ;;
        restart)
            stop_services
            sleep 2
            start_services
            check_services
            ;;
        status)
            docker-compose ps
            ;;
        logs)
            show_logs
            ;;
        cleanup)
            cleanup
            ;;
        build)
            check_docker
            check_config
            check_ports
            start_services "build"
            check_services
            show_connection_info
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_message $RED "❌ Comando desconocido: $command"
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal con todos los argumentos
main "$@"
