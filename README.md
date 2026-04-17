# SysCtrl Pro v2.0.0
## Panel de Control Avanzado para Debian/Linux

```
   ███████╗██╗   ██╗███████╗ ██████╗████████╗██████╗ ██╗
   ██╔════╝╚██╗ ██╔╝██╔════╝██╔════╝╚══██╔══╝██╔══██╗██║
   ███████╗ ╚████╔╝ ███████╗██║        ██║   ██████╔╝██║
   ╚════██║  ╚██╔╝  ╚════██║██║        ██║   ██╔══██╗██║
   ███████║   ██║   ███████║╚██████╗   ██║   ██║  ██║███████╗
   ╚══════╝   ╚═╝   ╚══════╝ ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
                  P R O  ─  Panel de Control Avanzado
```

---

## 📋 Descripción

SysCtrl Pro es una herramienta tipo **panel de control en Bash** para sistemas
Debian/Ubuntu que centraliza la administración, automatización y seguridad del
sistema de forma eficiente, visual y profesional.

---

## 🗂️ Estructura del Proyecto

```
sysctrl/
├── sysctrl.sh          ← Script principal (punto de entrada)
├── install.sh          ← Instalador
├── README.md           ← Este archivo
├── config/
│   └── sysctrl.conf    ← Configuración (auto-generada en 1ª ejecución)
├── data/
│   └── hosts.json      ← Base de datos de hosts SSH
├── logs/
│   └── actions.log     ← Historial de acciones
├── reports/            ← Informes de auditoría y exportaciones
└── plugins/            ← Scripts externos (sistema de plugins)
    ├── hardware_info.sh
    └── network_monitor.sh
```

---

## 🚀 Instalación Rápida

```bash
# Clonar o descargar los archivos
chmod +x sysctrl.sh install.sh

# Instalar (con sudo para enlace global)
sudo bash install.sh

# O ejecutar directamente
bash sysctrl.sh
```

### Dependencias opcionales (recomendadas)

```bash
sudo apt install -y jq nmap openssh-client rsync ufw fail2ban net-tools curl wget
```

| Herramienta | Para qué se usa |
|-------------|-----------------|
| `jq`        | Gestión de hosts en JSON (SSH Manager) |
| `nmap`      | Escaneo de red LAN |
| `ufw`       | Gestión de firewall |
| `fail2ban`  | Protección contra brute-force |
| `rsync`     | Transferencia de archivos |
| `net-tools` | Comando `netstat` |

---

## 🎯 Módulos y Funcionalidades

### 1️⃣ Interfaz de Usuario (UX)
- Animación de inicio con ASCII art y barra de carga
- Spinner dinámico para operaciones largas
- Colores ANSI: verde (OK), rojo (error), amarillo (aviso), cyan (info)
- Barra de estado en tiempo real en el menú principal
- Menú interactivo navegable

### 2️⃣ SSH Manager & Automatización
- **Guardar hosts** con alias, IP, usuario, puerto y clave SSH
- **Listar, editar y eliminar** hosts (almacenados en `data/hosts.json`)
- **Conexión directa** a cualquier host guardado
- **Ejecución remota** de comandos en un host
- **Modo batch**: ejecutar el mismo comando en TODOS los hosts
- **Transferencia de archivos** vía `scp` o `rsync`

### 3️⃣ Seguridad y Hardening
- Actualización completa del sistema (`update + upgrade + autoremove`)
- Gestión de **UFW** (habilitar/deshabilitar, añadir/eliminar reglas)
- Instalación y verificación de **Fail2Ban**
- Detección de **puertos abiertos** (`ss` / `netstat`)
- Revisión de **usuarios con shell**, UID 0, grupo sudo y archivos SUID
- Análisis de configuración **sshd_config** con recomendaciones
- Deshabilitar **root login SSH** con backup automático
- Revisión de **accesos fallidos** y logins recientes

### 4️⃣ Mantenimiento y Monitorización
- **Limpieza automática**: autoremove, autoclean, clean, vacuum de journal
- **Monitor en tiempo real** con barras de CPU/RAM/Disco + alertas
- Estado de servicios críticos (`ssh`, `ufw`, `fail2ban`, `cron`...)
- Top 10 procesos por consumo de CPU
- Uso de disco detallado (`df` + `du`)
- Limpieza de logs según antigüedad (días configurables)

### 5️⃣ Check Rápido del Sistema
Diagnóstico completo en un clic que evalúa:
- Configuración SSH segura
- Firewall y Fail2Ban activos
- Recursos dentro de umbrales
- Actualizaciones pendientes
- Puntuación final de salud del sistema (0-100%)

### 6️⃣ Tareas Programadas (Cron)
- Añadir tareas cron directamente desde el menú
- Listar y eliminar tareas creadas por SysCtrl
- Ver el crontab completo

### 7️⃣ Detección de Red LAN
- Escaneo automático de la subred local con `nmap`
- Muestra IP, MAC y fabricante de cada dispositivo

### 8️⃣ Sistema de Plugins
- Coloca cualquier `.sh` en el directorio `plugins/`
- Añade `# DESC: Descripción` al inicio del script
- Ejecutable desde el menú sin modificar el script principal
- Se incluyen dos plugins de ejemplo: `hardware_info` y `network_monitor`

### 9️⃣ Logs e Historial
- Todas las acciones se registran en `logs/actions.log` con timestamp y usuario
- Exportación de informes completos del sistema a `reports/`
- Visualización del journal del sistema

### 🔟 Modo Auditoría
Genera un informe de seguridad completo que evalúa:
- Configuración SSH (PermitRootLogin, PasswordAuth, Protocol)
- Estado de UFW y Fail2Ban
- Usuarios con UID 0 no esperados
- Recursos y actualizaciones pendientes
- Clasificación: PASS / WARN / FAIL con conteo de problemas

---

## ⚙️ Configuración (`config/sysctrl.conf`)

```bash
PROFILE="advanced"      # basic | advanced
VERBOSE="false"         # más información en pantalla
QUIET="false"           # sin animaciones (útil en scripts)
EDITOR="nano"           # editor para configuración
SSH_PORT="22"           # puerto SSH por defecto
SSH_TIMEOUT="10"        # timeout de conexión
ALERT_CPU=85            # % alerta CPU
ALERT_RAM=85            # % alerta RAM
ALERT_DISK=90           # % alerta disco
LOG_RETENTION=30        # días de retención de logs
```

---

## 🖥️ Uso desde línea de comandos

```bash
sysctrl                 # Menú interactivo
sysctrl --check         # Check rápido y salir
sysctrl --audit         # Auditoría de seguridad y salir
sysctrl --verbose       # Modo verbose
sysctrl --quiet         # Sin animaciones (para scripts/cron)
sysctrl --version       # Mostrar versión
sysctrl --help          # Ayuda
```

### Ejemplo: Check rápido desde cron (cada día a las 7:00)
```
0 7 * * * /usr/local/bin/sysctrl --quiet --check >> /var/log/sysctrl_daily.log 2>&1
```

---

## 🧩 Crear un Plugin Personalizado

```bash
#!/usr/bin/env bash
# DESC: Mi plugin personalizado
# AUTOR: Tu nombre

echo "Hola desde mi plugin!"
df -h /
```

Guarda el archivo en `plugins/mi_plugin.sh`, hazlo ejecutable y aparecerá
automáticamente en el menú de plugins.

---

## 🔒 Buenas Prácticas de Seguridad

1. Ejecuta SysCtrl con tu usuario habitual; usa `sudo` solo cuando sea necesario
2. Las claves SSH deben tener permisos `600`: `chmod 600 ~/.ssh/id_rsa`
3. Realiza backups del archivo de configuración antes de modificarlo
4. Revisa regularmente el log de acciones: `cat logs/actions.log`
5. Programa auditorías automáticas con cron

---

## 📝 Notas Técnicas

- **Compatible con**: Debian 10+, Ubuntu 20.04+, Raspberry Pi OS
- **Shell**: Bash 4.0 o superior
- **No requiere instalación** de dependencias para funcionar en modo básico
- `jq` es opcional pero **muy recomendado** para el SSH Manager
- Diseñado con `set -euo pipefail` para manejo robusto de errores
- Código modular: cada sección es independiente y fácilmente ampliable

---

## 📄 Licencia

MIT License — Libre para uso personal y profesional.

---

*SysCtrl Pro v2.0.0 · Panel de Control Bash para Debian/Linux*
