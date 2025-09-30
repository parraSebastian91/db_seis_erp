# 🐳 Dockerización de ms-auth

Esta guía explica cómo ejecutar la aplicación NestJS con Docker y Docker Compose.

## 📋 Prerrequisitos

- Docker >= 20.10.0
- Docker Compose >= 2.0.0

## 🏗️ Arquitectura

La aplicación está compuesta por tres servicios:

1. **ms-auth**: Aplicación NestJS (Puerto 3000)
2. **PostgreSQL**: Base de datos (Puerto 5432)
3. **Redis**: Cache y sesiones (Puerto 6379)

## 🚀 Inicio Rápido

### Desarrollo

```bash
# Construir las imágenes
./docker-build.sh

# Iniciar en modo desarrollo (con hot-reload)
./docker-dev.sh

# Ver logs en tiempo real
docker-compose logs -f ms-auth
```

### Producción

```bash
# Iniciar en modo producción
./docker-prod.sh

# Ver logs
docker-compose -f docker-compose.prod.yml logs -f ms-auth
```

## 📂 Archivos de Configuración

### Desarrollo
- `docker-compose.yml`: Configuración para desarrollo
- Variables de entorno definidas directamente en el compose

### Producción
- `docker-compose.prod.yml`: Configuración para producción
- `.env.docker`: Variables de entorno (copia y personaliza)

## 🔧 Variables de Entorno

Copia `.env.docker` y ajusta los valores:

```bash
cp .env.docker .env.production
```

Variables importantes:
- `JWT_SECRET`: Clave secreta para JWT (cambiar en producción)
- `DATABASE_PASSWORD`: Contraseña de PostgreSQL
- `NODE_ENV`: Ambiente (development/production)

## 🛠️ Comandos Útiles

```bash
# Construir solo la aplicación
docker-compose build ms-auth

# Reconstruir sin cache
docker-compose build --no-cache ms-auth

# Ver estado de servicios
docker-compose ps

# Ejecutar comandos dentro del contenedor
docker-compose exec ms-auth npm run test

# Ver logs de un servicio específico
docker-compose logs -f postgres

# Reiniciar un servicio
docker-compose restart ms-auth

# Detener todos los servicios
docker-compose down

# Detener y eliminar volúmenes (⚠️ elimina datos)
docker-compose down -v
```

## 🧹 Limpieza

```bash
# Limpiar contenedores, imágenes y cache
./docker-clean.sh
```

## 🔍 Health Check

La aplicación incluye un endpoint de health check:

- **URL**: `http://localhost:3000/health`
- **Método**: GET
- **Respuesta**:
```json
{
  "status": "ok",
  "timestamp": "2025-09-28T...",
  "uptime": 123.45,
  "environment": "development"
}
```

## 🔒 Seguridad en Producción

1. **Cambiar credenciales por defecto**:
   - JWT_SECRET
   - DATABASE_PASSWORD

2. **Configurar variables de entorno**:
   ```bash
   # No usar credenciales por defecto
   DATABASE_PASSWORD=tu_password_segura
   JWT_SECRET=tu_jwt_secret_muy_largo_y_seguro
   ```

3. **Limitar puertos expuestos** en producción si es necesario

## 🐛 Troubleshooting

### Problema: No se puede conectar a PostgreSQL
```bash
# Verificar que PostgreSQL esté listo
docker exec core_erp_postgres pg_isready -U desarrollo -d core_erp

# Ver logs de PostgreSQL
docker-compose logs postgres
```

### Problema: Aplicación no inicia
```bash
# Verificar logs de la aplicación
docker-compose logs ms-auth

# Rebuilder la imagen
docker-compose build --no-cache ms-auth
```

### Problema: Puerto en uso
```bash
# Cambiar puertos en docker-compose.yml si hay conflictos
ports:
  - "3001:3000"  # Usar puerto 3001 en lugar de 3000
```

## 📊 Monitoreo

### Ver recursos utilizados
```bash
docker stats
```

### Ver espacio en disco
```bash
docker system df
```

### Inspeccionar contenedor
```bash
docker inspect core_erp_ms_auth
```

## 🔄 Actualización

Para actualizar la aplicación:

1. Hacer pull de cambios
2. Reconstruir imagen: `./docker-build.sh`
3. Reiniciar servicios: `docker-compose restart ms-auth`
