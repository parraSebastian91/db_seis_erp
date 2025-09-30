# Entorno Dockerizado ERP - Base de Datos

Este proyecto contiene la configuración dockerizada para el entorno de base de datos del ERP SEIS, incluyendo PostgreSQL y Redis.

## 🚀 Inicio Rápido

### Prerequisitos
- Docker
- Docker Compose

### Configuración

1. **Clonar/Ubicarse en el directorio del proyecto**
   ```bash
   cd /Users/Desarrollo/Documents/Proyectos/ERP/DB/db_seis_erp
   ```

2. **Configurar variables de entorno (opcional)**
   ```bash
   cp .env.example .env
   # Editar .env si necesitas cambiar las configuraciones por defecto
   ```

3. **Levantar los servicios**
   ```bash
   docker-compose up -d
   ```

## 📦 Servicios Incluidos

### PostgreSQL
- **Puerto**: 5432
- **Base de datos**: core_erp
- **Usuario**: desarrollo
- **Contraseña**: desarrollo123
- **Inicialización**: Los scripts SQL en `init-db/` se ejecutan automáticamente

### Redis
- **Puerto**: 6379
- **Configuración**: redis/redis.conf
- **Persistencia**: Habilitada (RDB + AOF)

### PgAdmin (Herramienta de administración PostgreSQL)
- **URL**: http://localhost:8080
- **Email**: admin@seiserp.com
- **Contraseña**: admin123

### Redis Commander (Herramienta de administración Redis)
- **URL**: http://localhost:8081
- **Usuario**: admin
- **Contraseña**: admin123

## 🔧 Comandos Útiles

### Gestión de contenedores
```bash
# Levantar servicios
docker-compose up -d

# Ver logs
docker-compose logs -f

# Parar servicios
docker-compose stop

# Eliminar contenedores (mantiene volúmenes)
docker-compose down

# Eliminar todo (incluyendo volúmenes de datos)
docker-compose down -v
```

### Acceso directo a los servicios

#### PostgreSQL
```bash
# Conectar desde línea de comandos
docker-compose exec postgres psql -U desarrollo -d core_erp

# Conectar desde aplicación externa
# Host: localhost
# Port: 5432
# Database: core_erp
# Username: desarrollo
# Password: desarrollo123
```

#### Redis
```bash
# Conectar desde línea de comandos
docker-compose exec redis redis-cli

# Conectar desde aplicación externa
# Host: localhost
# Port: 6379
```

## 📁 Estructura del Proyecto

```
.
├── docker-compose.yml          # Configuración principal de Docker Compose
├── .env.example               # Variables de entorno de ejemplo
├── redis/
│   └── redis.conf            # Configuración de Redis
├── init-db/                  # Scripts de inicialización de PostgreSQL
│   ├── init_core.sql
│   ├── init_core_insert.sql
│   ├── init_bodega.sql
│   └── init_bodega_insert.sql
└── diagramas/                # Documentación de la base de datos
```

## 🔍 Healthchecks

Los servicios incluyen healthchecks para verificar su estado:

```bash
# Ver estado de los servicios
docker-compose ps

# Ver detalles de health de un servicio específico
docker inspect seis_erp_postgres | grep Health -A 20
```

## 🔒 Seguridad

### Para Producción:
1. Cambiar todas las contraseñas por defecto
2. Configurar autenticación en Redis
3. Limitar acceso de red a los puertos de base de datos
4. Usar certificados SSL/TLS

### Configuración de Redis con autenticación:
Descomenta la línea `requirepass` en `redis/redis.conf` y establece una contraseña segura.

## 🐛 Resolución de Problemas

### Los servicios no inician
```bash
# Ver logs detallados
docker-compose logs

# Verificar puertos en uso
netstat -an | grep -E "(5432|6379|8080|8081)"
```

### Cambiar puertos en caso de conflicto
Edita el archivo `.env` o directamente `docker-compose.yml` para cambiar los puertos mapeados.

### Reinicializar base de datos
```bash
# Eliminar volúmenes y reiniciar
docker-compose down -v
docker-compose up -d
```

## 📊 Monitoreo

Los servicios incluyen healthchecks que puedes monitorear:

```bash
# Estado de salud de PostgreSQL
docker-compose exec postgres pg_isready -U desarrollo -d core_erp

# Estado de salud de Redis
docker-compose exec redis redis-cli ping
```

## 🔄 Backup y Restore

### PostgreSQL
```bash
# Backup
docker-compose exec postgres pg_dump -U desarrollo core_erp > backup.sql

# Restore
docker-compose exec -T postgres psql -U desarrollo core_erp < backup.sql
```

### Redis
```bash
# Backup (RDB)
docker-compose exec redis redis-cli BGSAVE

# Los archivos se guardan en el volumen redis_data
```
