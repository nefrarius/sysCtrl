#!/usr/bin/env bash
# =============================================================================
#  SysCtrl Pro - Panel de Control Avanzado para Debian/Linux
#  Versión: 2.0.0
#  Autor: SysCtrl Team
#  Descripción: Herramienta modular de administración, automatización y
#               seguridad para sistemas Debian/Linux.
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# SECCIÓN 1: RUTAS Y CONSTANTES GLOBALES
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="2.0.0"
readonly CONFIG_DIR="${SCRIPT_DIR}/config"
readonly DATA_DIR="${SCRIPT_DIR}/data"
readonly LOGS_DIR="${SCRIPT_DIR}/logs"
readonly PLUGINS_DIR="${SCRIPT_DIR}/plugins"
readonly REPORTS_DIR="${SCRIPT_DIR}/reports"
readonly CONFIG_FILE="${CONFIG_DIR}/sysctrl.conf"
readonly HOSTS_FILE="${DATA_DIR}/hosts.json"
readonly ACTION_LOG="${LOGS_DIR}/actions.log"
readonly CRON_TAG="# SysCtrl-Pro-Task"

# Umbrales de alerta
readonly CPU_THRESHOLD=85
readonly RAM_THRESHOLD=85
readonly DISK_THRESHOLD=90

# =============================================================================
# SECCIÓN 2: COLORES Y ESTILOS ANSI
# =============================================================================

# Colores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;37m'
readonly ORANGE='\033[38;5;208m'

# Estilos
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly ITALIC='\033[3m'
readonly UNDERLINE='\033[4m'
readonly BLINK='\033[5m'
readonly RESET='\033[0m'

# Fondos
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'
readonly BG_BLUE='\033[44m'
readonly BG_CYAN='\033[46m'
readonly BG_DARK='\033[48;5;235m'

# Iconos Unicode
readonly ICON_OK="✓"
readonly ICON_FAIL="✗"
readonly ICON_WARN="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_ARROW="▶"
readonly ICON_BULLET="•"
readonly ICON_GEAR="⚙"
readonly ICON_SHIELD="🛡"
readonly ICON_ROCKET="🚀"
readonly ICON_FIRE="🔥"
readonly ICON_LOCK="🔒"
readonly ICON_NET="🌐"
readonly ICON_DISK="💾"
readonly ICON_CPU="⚡"
readonly ICON_RAM="🧠"
readonly ICON_LOG="📋"
readonly ICON_PLUGIN="🧩"
readonly ICON_CRON="⏱"
readonly ICON_AUDIT="🔍"

# =============================================================================
# SECCIÓN 3: FUNCIONES DE MENSAJERÍA Y UX
# =============================================================================

# Imprime mensaje de éxito
msg_ok() {
    echo -e "${GREEN}${BOLD}  ${ICON_OK}${RESET} ${GREEN}$*${RESET}"
}

# Imprime mensaje de error
msg_error() {
    echo -e "${RED}${BOLD}  ${ICON_FAIL}${RESET} ${RED}$*${RESET}" >&2
}

# Imprime advertencia
msg_warn() {
    echo -e "${YELLOW}${BOLD}  ${ICON_WARN}${RESET} ${YELLOW}$*${RESET}"
}

# Imprime información
msg_info() {
    echo -e "${CYAN}${BOLD}  ${ICON_INFO}${RESET} ${CYAN}$*${RESET}"
}

# Sección/cabecera
msg_section() {
    local title="$1"
    local width=60
    local border
    border=$(printf '─%.0s' $(seq 1 $width))
    echo ""
    echo -e "${CYAN}${BOLD}┌${border}┐${RESET}"
    printf "${CYAN}${BOLD}│${RESET} ${BOLD}${WHITE}%-${width}s${RESET}${CYAN}${BOLD}│${RESET}\n" "  $title"
    echo -e "${CYAN}${BOLD}└${border}┘${RESET}"
}

# Separador simple
separator() {
    echo -e "${DIM}${GRAY}$(printf '─%.0s' $(seq 1 62))${RESET}"
}

# Pausa con mensaje
pause() {
    echo ""
    read -rp "$(echo -e "${DIM}  Pulsa ${CYAN}[Enter]${RESET}${DIM} para continuar...${RESET}")"
}

# Confirmación
confirm() {
    local prompt="${1:-¿Estás seguro?}"
    local response
    echo -e "${YELLOW}${BOLD}  ${ICON_WARN} ${prompt} [s/N]: ${RESET}"
    read -r response
    [[ "$response" =~ ^[sS]$ ]]
}

# Spinner animado
spinner() {
    local pid=$1
    local message="${2:-Procesando...}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}${frames[$i]}${RESET} ${DIM}${message}${RESET}   "
        i=$(( (i+1) % ${#frames[@]} ))
        sleep 0.1
    done
    tput cnorm 2>/dev/null || true
    printf "\r  ${GREEN}${ICON_OK}${RESET} ${message}   \n"
}

# Barra de progreso
progress_bar() {
    local current=$1
    local total=$2
    local label="${3:-}"
    local width=40
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    local bar
    bar="${GREEN}$(printf '█%.0s' $(seq 1 $filled))${RESET}${DIM}$(printf '░%.0s' $(seq 1 $empty))${RESET}"
    local pct=$(( current * 100 / total ))
    printf "\r  [%s] ${BOLD}%3d%%${RESET} %s" "$bar" "$pct" "$label"
}

# =============================================================================
# SECCIÓN 4: REGISTRO DE ACCIONES (LOG)
# =============================================================================

log_action() {
    local action="$1"
    local status="${2:-OK}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user
    user=$(whoami)
    mkdir -p "$LOGS_DIR"
    echo "[$timestamp] [USER:$user] [${status}] $action" >> "$ACTION_LOG"
}

# =============================================================================
# SECCIÓN 5: ANIMACIÓN DE INICIO
# =============================================================================

show_splash() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
   ███████╗██╗   ██╗███████╗ ██████╗████████╗██████╗ ██╗     
   ██╔════╝╚██╗ ██╔╝██╔════╝██╔════╝╚══██╔══╝██╔══██╗██║     
   ███████╗ ╚████╔╝ ███████╗██║        ██║   ██████╔╝██║     
   ╚════██║  ╚██╔╝  ╚════██║██║        ██║   ██╔══██╗██║     
   ███████║   ██║   ███████║╚██████╗   ██║   ██║  ██║███████╗
   ╚══════╝   ╚═╝   ╚══════╝ ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
EOF
    echo -e "${RESET}"
    echo -e "         ${MAGENTA}${BOLD}P R O${RESET}  ${DIM}─  Panel de Control Avanzado para Linux${RESET}"
    echo -e "         ${DIM}v${VERSION}  │  Debian/Ubuntu  │  By SysCtrl Team${RESET}"
    echo ""
    separator
    echo ""

    # Barra de carga animada
    echo -e "  ${DIM}Inicializando módulos...${RESET}"
    echo ""
    local modules=("Core" "Seguridad" "SSH Manager" "Monitoring" "Firewall" "Plugins")
    local total=${#modules[@]}
    for i in "${!modules[@]}"; do
        sleep 0.18
        progress_bar $((i+1)) $total "Cargando ${modules[$i]}..."
    done
    echo ""
    echo ""
    sleep 0.3
    msg_ok "Sistema listo. Bienvenido, $(whoami)."
    echo ""
    sleep 0.5
}

# =============================================================================
# SECCIÓN 6: INICIALIZACIÓN Y CONFIGURACIÓN
# =============================================================================

init_dirs() {
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOGS_DIR" "$PLUGINS_DIR" "$REPORTS_DIR"
}

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        create_default_config
    fi
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
}

create_default_config() {
    cat > "$CONFIG_FILE" << 'CONF'
# SysCtrl Pro - Configuración Principal
# Edita este archivo para personalizar el comportamiento

# Perfil del usuario: basic | advanced
PROFILE="advanced"

# Modo verbose: true | false
VERBOSE="false"

# Modo silencioso: true | false
QUIET="false"

# Editor preferido
EDITOR="${EDITOR:-nano}"

# SSH opciones por defecto
SSH_PORT="22"
SSH_TIMEOUT="10"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

# Umbrales de alerta (porcentajes)
ALERT_CPU=85
ALERT_RAM=85
ALERT_DISK=90

# Colores habilitados: true | false
USE_COLORS="true"

# Nombre del servidor (para informes)
SERVER_ALIAS="$(hostname)"

# Retención de logs (días)
LOG_RETENTION=30
CONF
    msg_ok "Configuración por defecto creada en ${CONFIG_FILE}"
    log_action "Configuración por defecto generada"
}

init_hosts_file() {
    if [[ ! -f "$HOSTS_FILE" ]]; then
        echo '{"hosts":[]}' > "$HOSTS_FILE"
    fi
}

# =============================================================================
# SECCIÓN 7: MENÚ PRINCIPAL
# =============================================================================

show_main_menu() {
    while true; do
        clear
        echo ""
        echo -e "${BG_DARK}${CYAN}${BOLD}  ╔══════════════════════════════════════════════════════════╗  ${RESET}"
        echo -e "${BG_DARK}${CYAN}${BOLD}  ║   ${ICON_ROCKET}  SysCtrl Pro ${DIM}v${VERSION}${RESET}${BG_DARK}${CYAN}${BOLD}   ·   $(hostname)   ║  ${RESET}"
        echo -e "${BG_DARK}${CYAN}${BOLD}  ╚══════════════════════════════════════════════════════════╝  ${RESET}"
        echo ""

        # Estado rápido en el menú
        _show_quick_status_bar

        echo ""
        echo -e "  ${BOLD}${WHITE}MENÚ PRINCIPAL${RESET}"
        separator
        echo ""
        echo -e "  ${CYAN}${BOLD}1${RESET}  ${ICON_GEAR}  Automatización SSH & Hosts"
        echo -e "  ${CYAN}${BOLD}2${RESET}  ${ICON_SHIELD}  Seguridad y Hardening"
        echo -e "  ${CYAN}${BOLD}3${RESET}  ${ICON_CPU}  Mantenimiento y Monitorización"
        echo -e "  ${CYAN}${BOLD}4${RESET}  ${ICON_AUDIT}  Check Rápido del Sistema"
        echo -e "  ${CYAN}${BOLD}5${RESET}  ${ICON_CRON}  Tareas Programadas (Cron)"
        echo -e "  ${CYAN}${BOLD}6${RESET}  ${ICON_NET}  Detección de Red LAN"
        echo -e "  ${CYAN}${BOLD}7${RESET}  ${ICON_PLUGIN}  Gestión de Plugins"
        echo -e "  ${CYAN}${BOLD}8${RESET}  ${ICON_LOG}  Historial y Logs"
        echo -e "  ${CYAN}${BOLD}9${RESET}  ${ICON_GEAR}  Configuración"
        echo -e "  ${CYAN}${BOLD}0${RESET}  ${ICON_ROCKET}  Modo Auditoría (Informe)"
        echo ""
        separator
        echo -e "  ${RED}${BOLD}q${RESET}  Salir"
        echo ""
        read -rp "$(echo -e "  ${BOLD}Selección ${CYAN}»${RESET} ")" choice

        case "$choice" in
            1) menu_ssh ;;
            2) menu_security ;;
            3) menu_maintenance ;;
            4) quick_check ;;
            5) menu_cron ;;
            6) scan_lan ;;
            7) menu_plugins ;;
            8) menu_logs ;;
            9) menu_config ;;
            0) run_audit ;;
            q|Q) exit_script ;;
            *) msg_warn "Opción no válida. Intenta de nuevo." ; sleep 1 ;;
        esac
    done
}

_show_quick_status_bar() {
    local cpu ram disk
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}' 2>/dev/null || echo "?")
    ram=$(free | awk '/^Mem/ {printf "%d", $3/$2*100}' 2>/dev/null || echo "?")
    disk=$(df / | awk 'NR==2 {print int($5)}' 2>/dev/null || echo "?")

    local cpu_color="${GREEN}" ram_color="${GREEN}" disk_color="${GREEN}"
    [[ "$cpu" != "?" && "$cpu" -ge "$CPU_THRESHOLD" ]] && cpu_color="${RED}"
    [[ "$ram" != "?" && "$ram" -ge "$RAM_THRESHOLD" ]] && ram_color="${RED}"
    [[ "$disk" != "?" && "$disk" -ge "$DISK_THRESHOLD" ]] && disk_color="${RED}"

    echo -e "  ${DIM}Estado:${RESET}  ${ICON_CPU} CPU ${cpu_color}${BOLD}${cpu}%${RESET}   ${ICON_RAM} RAM ${ram_color}${BOLD}${ram}%${RESET}   ${ICON_DISK} Disco ${disk_color}${BOLD}${disk}%${RESET}   ${DIM}$(date '+%H:%M:%S')${RESET}"
}

# =============================================================================
# SECCIÓN 8: MÓDULO SSH - GESTIÓN DE HOSTS
# =============================================================================

menu_ssh() {
    while true; do
        clear
        msg_section "${ICON_GEAR}  SSH Manager & Gestión de Hosts"
        echo ""
        echo -e "  ${CYAN}${BOLD}1${RESET}  Listar hosts guardados"
        echo -e "  ${CYAN}${BOLD}2${RESET}  Añadir nuevo host"
        echo -e "  ${CYAN}${BOLD}3${RESET}  Conectar a un host"
        echo -e "  ${CYAN}${BOLD}4${RESET}  Ejecutar comando remoto"
        echo -e "  ${CYAN}${BOLD}5${RESET}  Ejecutar en TODOS los hosts (batch)"
        echo -e "  ${CYAN}${BOLD}6${RESET}  Transferir archivo (scp/rsync)"
        echo -e "  ${CYAN}${BOLD}7${RESET}  Editar host"
        echo -e "  ${CYAN}${BOLD}8${RESET}  Eliminar host"
        echo -e "  ${CYAN}${BOLD}b${RESET}  Volver"
        echo ""
        read -rp "$(echo -e "  ${BOLD}Selección ${CYAN}»${RESET} ")" choice
        case "$choice" in
            1) ssh_list_hosts ;;
            2) ssh_add_host ;;
            3) ssh_connect ;;
            4) ssh_remote_command ;;
            5) ssh_batch_command ;;
            6) ssh_transfer ;;
            7) ssh_edit_host ;;
            8) ssh_delete_host ;;
            b|B) return ;;
            *) msg_warn "Opción no válida" ; sleep 1 ;;
        esac
    done
}

# Requiere jq para JSON; fallback a formato simple si no está disponible
_jq_available() { command -v jq &>/dev/null; }

ssh_list_hosts() {
    msg_section "Hosts Guardados"
    if _jq_available; then
        local count
        count=$(jq '.hosts | length' "$HOSTS_FILE")
        if [[ "$count" -eq 0 ]]; then
            msg_warn "No hay hosts guardados aún."
        else
            printf "\n  ${BOLD}%-4s %-15s %-20s %-6s %-20s${RESET}\n" "ID" "Alias" "Host/IP" "Puerto" "Usuario"
            separator
            jq -r '.hosts[] | "\(.id)|\(.alias)|\(.host)|\(.port)|\(.user)"' "$HOSTS_FILE" | \
            while IFS='|' read -r id alias host port user; do
                printf "  ${CYAN}%-4s${RESET} %-15s %-20s %-6s %-20s\n" "$id" "$alias" "$host" "$port" "$user"
            done
        fi
    else
        msg_warn "jq no instalado. Mostrando hosts en formato básico."
        cat "$HOSTS_FILE"
    fi
    pause
}

ssh_add_host() {
    msg_section "Añadir Nuevo Host"
    local alias host user port key_path

    read -rp "$(echo -e "  Alias (ej: raspberry-pi): ")" alias
    read -rp "$(echo -e "  IP/Hostname: ")" host
    read -rp "$(echo -e "  Usuario [pi]: ")" user
    user="${user:-pi}"
    read -rp "$(echo -e "  Puerto SSH [22]: ")" port
    port="${port:-22}"
    read -rp "$(echo -e "  Ruta clave privada SSH (vacío para password): ")" key_path

    # Validar IP/hostname básico
    if [[ -z "$host" ]]; then
        msg_error "El host no puede estar vacío."
        pause; return
    fi

    local id
    id=$(date +%s)

    if _jq_available; then
        local tmp
        tmp=$(mktemp)
        jq --arg id "$id" --arg alias "$alias" --arg host "$host" \
           --arg user "$user" --arg port "$port" --arg key "$key_path" \
           '.hosts += [{"id":$id,"alias":$alias,"host":$host,"user":$user,"port":$port,"key":$key}]' \
           "$HOSTS_FILE" > "$tmp" && mv "$tmp" "$HOSTS_FILE"
    else
        echo "{\"id\":\"$id\",\"alias\":\"$alias\",\"host\":\"$host\",\"user\":\"$user\",\"port\":\"$port\",\"key\":\"$key_path\"}" >> "$HOSTS_FILE"
    fi

    msg_ok "Host '${alias}' guardado correctamente."
    log_action "Host añadido: $alias ($host:$port) usuario: $user"
    pause
}

_select_host() {
    # Muestra lista y devuelve los datos del host seleccionado en variables globales
    ssh_list_hosts
    read -rp "$(echo -e "  Introduce el ${BOLD}Alias${RESET} del host: ")" _SEL_ALIAS
    if _jq_available; then
        _SEL_HOST=$(jq -r --arg a "$_SEL_ALIAS" '.hosts[] | select(.alias==$a) | .host' "$HOSTS_FILE")
        _SEL_USER=$(jq -r --arg a "$_SEL_ALIAS" '.hosts[] | select(.alias==$a) | .user' "$HOSTS_FILE")
        _SEL_PORT=$(jq -r --arg a "$_SEL_ALIAS" '.hosts[] | select(.alias==$a) | .port' "$HOSTS_FILE")
        _SEL_KEY=$(jq -r --arg a "$_SEL_ALIAS" '.hosts[] | select(.alias==$a) | .key' "$HOSTS_FILE")
    fi
    if [[ -z "${_SEL_HOST:-}" ]]; then
        msg_error "Host no encontrado: $_SEL_ALIAS"
        return 1
    fi
}

ssh_connect() {
    msg_section "Conectar a Host SSH"
    _select_host || { pause; return; }

    local ssh_cmd="ssh -p ${_SEL_PORT} ${SSH_OPTS:-}"
    [[ -n "${_SEL_KEY}" && "${_SEL_KEY}" != "null" ]] && ssh_cmd+=" -i ${_SEL_KEY}"
    ssh_cmd+=" ${_SEL_USER}@${_SEL_HOST}"

    msg_info "Conectando a ${_SEL_ALIAS} (${_SEL_USER}@${_SEL_HOST}:${_SEL_PORT})..."
    log_action "Conexión SSH a ${_SEL_ALIAS} (${_SEL_HOST}:${_SEL_PORT})"
    eval "$ssh_cmd"
}

ssh_remote_command() {
    msg_section "Ejecutar Comando Remoto"
    _select_host || { pause; return; }
    read -rp "$(echo -e "  Comando a ejecutar: ")" remote_cmd
    if [[ -z "$remote_cmd" ]]; then msg_error "Comando vacío."; pause; return; fi

    local ssh_cmd="ssh -p ${_SEL_PORT} ${SSH_OPTS:-}"
    [[ -n "${_SEL_KEY}" && "${_SEL_KEY}" != "null" ]] && ssh_cmd+=" -i ${_SEL_KEY}"
    ssh_cmd+=" ${_SEL_USER}@${_SEL_HOST} \"$remote_cmd\""

    msg_info "Ejecutando en ${_SEL_ALIAS}: $remote_cmd"
    echo ""
    separator
    eval "$ssh_cmd" && msg_ok "Comando ejecutado correctamente." || msg_error "Error al ejecutar el comando."
    log_action "Comando remoto en ${_SEL_ALIAS}: $remote_cmd"
    pause
}

ssh_batch_command() {
    msg_section "Ejecución en Batch (todos los hosts)"
    read -rp "$(echo -e "  Comando a ejecutar en TODOS los hosts: ")" batch_cmd
    if [[ -z "$batch_cmd" ]]; then msg_error "Comando vacío."; pause; return; fi
    confirm "¿Ejecutar '${batch_cmd}' en todos los hosts?" || { msg_warn "Cancelado."; pause; return; }

    if _jq_available; then
        jq -r '.hosts[] | "\(.alias)|\(.host)|\(.user)|\(.port)|\(.key)"' "$HOSTS_FILE" | \
        while IFS='|' read -r alias host user port key; do
            echo ""
            echo -e "  ${CYAN}${BOLD}[${alias}]${RESET} ${DIM}${user}@${host}:${port}${RESET}"
            local ssh_cmd="ssh -p ${port} ${SSH_OPTS:-}"
            [[ -n "$key" && "$key" != "null" ]] && ssh_cmd+=" -i $key"
            ssh_cmd+=" ${user}@${host} \"$batch_cmd\""
            eval "$ssh_cmd" && msg_ok "OK" || msg_error "Error en ${alias}"
        done
    else
        msg_warn "jq requerido para modo batch."
    fi
    log_action "Batch remoto en todos los hosts: $batch_cmd"
    pause
}

ssh_transfer() {
    msg_section "Transferencia de Archivos (scp/rsync)"
    _select_host || { pause; return; }
    echo -e "  ${CYAN}1${RESET} scp   ${CYAN}2${RESET} rsync"
    read -rp "$(echo -e "  Método [1]: ")" method
    method="${method:-1}"
    read -rp "$(echo -e "  Archivo/directorio local: ")" local_path
    read -rp "$(echo -e "  Ruta destino remota [~]: ")" remote_path
    remote_path="${remote_path:-~}"

    if [[ "$method" == "2" ]]; then
        rsync -avz -e "ssh -p ${_SEL_PORT} ${SSH_OPTS:-}" "$local_path" "${_SEL_USER}@${_SEL_HOST}:${remote_path}" \
            && msg_ok "Transferencia rsync completada." || msg_error "Error en rsync."
    else
        scp -P "${_SEL_PORT}" ${SSH_OPTS:-} "$local_path" "${_SEL_USER}@${_SEL_HOST}:${remote_path}" \
            && msg_ok "Transferencia scp completada." || msg_error "Error en scp."
    fi
    log_action "Transferencia a ${_SEL_ALIAS}: $local_path → $remote_path"
    pause
}

ssh_edit_host() {
    msg_section "Editar Host"
    if _jq_available; then
        read -rp "$(echo -e "  Alias del host a editar: ")" alias
        local exists
        exists=$(jq --arg a "$alias" '.hosts[] | select(.alias==$a)' "$HOSTS_FILE")
        if [[ -z "$exists" ]]; then msg_error "Host no encontrado."; pause; return; fi
        msg_info "Introduce nuevos valores (Enter para mantener actual)"
        local new_host new_user new_port new_key
        read -rp "  Nuevo IP/Hostname: " new_host
        read -rp "  Nuevo usuario: " new_user
        read -rp "  Nuevo puerto: " new_port
        read -rp "  Nueva clave SSH: " new_key
        local tmp; tmp=$(mktemp)
        jq --arg a "$alias" \
           --arg h "$new_host" --arg u "$new_user" --arg p "$new_port" --arg k "$new_key" '
          .hosts |= map(if .alias == $a then
            . * {
              host: (if $h != "" then $h else .host end),
              user: (if $u != "" then $u else .user end),
              port: (if $p != "" then $p else .port end),
              key:  (if $k != "" then $k else .key end)
            }
          else . end)' "$HOSTS_FILE" > "$tmp" && mv "$tmp" "$HOSTS_FILE"
        msg_ok "Host '$alias' actualizado."
        log_action "Host editado: $alias"
    else
        msg_warn "jq requerido para editar hosts."
    fi
    pause
}

ssh_delete_host() {
    msg_section "Eliminar Host"
    read -rp "$(echo -e "  Alias del host a eliminar: ")" alias
    confirm "¿Eliminar host '${alias}'?" || { msg_warn "Cancelado."; pause; return; }
    if _jq_available; then
        local tmp; tmp=$(mktemp)
        jq --arg a "$alias" '.hosts |= map(select(.alias != $a))' "$HOSTS_FILE" > "$tmp" && mv "$tmp" "$HOSTS_FILE"
        msg_ok "Host '$alias' eliminado."
        log_action "Host eliminado: $alias"
    fi
    pause
}

# =============================================================================
# SECCIÓN 9: MÓDULO SEGURIDAD Y HARDENING
# =============================================================================

menu_security() {
    while true; do
        clear
        msg_section "${ICON_SHIELD}  Seguridad y Hardening"
        echo ""
        echo -e "  ${CYAN}${BOLD}1${RESET}  Actualizar el sistema (apt)"
        echo -e "  ${CYAN}${BOLD}2${RESET}  Gestionar Firewall (ufw)"
        echo -e "  ${CYAN}${BOLD}3${RESET}  Instalar/Configurar Fail2Ban"
        echo -e "  ${CYAN}${BOLD}4${RESET}  Detectar puertos abiertos"
        echo -e "  ${CYAN}${BOLD}5${RESET}  Revisar usuarios y permisos"
        echo -e "  ${CYAN}${BOLD}6${RESET}  Verificar configuración SSH"
        echo -e "  ${CYAN}${BOLD}7${RESET}  Deshabilitar login root SSH"
        echo -e "  ${CYAN}${BOLD}8${RESET}  Revisar accesos sospechosos"
        echo -e "  ${CYAN}${BOLD}b${RESET}  Volver"
        echo ""
        read -rp "$(echo -e "  ${BOLD}Selección ${CYAN}»${RESET} ")" choice
        case "$choice" in
            1) sec_update_system ;;
            2) sec_manage_ufw ;;
            3) sec_fail2ban ;;
            4) sec_open_ports ;;
            5) sec_users_perms ;;
            6) sec_check_ssh_config ;;
            7) sec_disable_root_login ;;
            8) sec_suspicious_access ;;
            b|B) return ;;
            *) msg_warn "Opción no válida" ; sleep 1 ;;
        esac
    done
}

sec_update_system() {
    msg_section "Actualización del Sistema"
    _require_root || return
    msg_info "Ejecutando apt update..."
    apt-get update 2>&1 | tail -5 &
    spinner $! "Actualizando lista de paquetes"
    msg_info "Ejecutando apt upgrade..."
    apt-get upgrade -y 2>&1 | tail -5 &
    spinner $! "Actualizando paquetes"
    msg_info "Ejecutando autoremove..."
    apt-get autoremove -y &>/dev/null &
    spinner $! "Limpiando paquetes no necesarios"
    msg_ok "Sistema actualizado correctamente."
    log_action "Sistema actualizado (apt update && upgrade && autoremove)"
    pause
}

sec_manage_ufw() {
    msg_section "Gestión de Firewall (UFW)"
    _require_root || return
    if ! command -v ufw &>/dev/null; then
        msg_warn "UFW no instalado. ¿Instalar ahora?"
        confirm "¿Instalar ufw?" && apt-get install -y ufw && msg_ok "UFW instalado."
    fi
    echo ""
    echo -e "  Estado actual:"
    ufw status verbose 2>/dev/null || msg_warn "UFW no responde."
    echo ""
    echo -e "  ${CYAN}1${RESET} Habilitar UFW   ${CYAN}2${RESET} Deshabilitar   ${CYAN}3${RESET} Permitir puerto   ${CYAN}4${RESET} Denegar puerto   ${CYAN}5${RESET} Ver reglas   ${CYAN}b${RESET} Volver"
    read -rp "$(echo -e "  Opción: ")" opt
    case "$opt" in
        1) ufw enable && msg_ok "UFW habilitado." && log_action "UFW habilitado" ;;
        2) ufw disable && msg_ok "UFW deshabilitado." && log_action "UFW deshabilitado" ;;
        3)
            read -rp "  Puerto a permitir (ej: 22/tcp): " p
            ufw allow "$p" && msg_ok "Puerto $p permitido." && log_action "UFW: puerto $p permitido"
            ;;
        4)
            read -rp "  Puerto a denegar: " p
            ufw deny "$p" && msg_ok "Puerto $p denegado." && log_action "UFW: puerto $p denegado"
            ;;
        5) ufw status numbered ;;
        b|B) return ;;
    esac
    pause
}

sec_fail2ban() {
    msg_section "Fail2Ban"
    _require_root || return
    if ! command -v fail2ban-client &>/dev/null; then
        confirm "Fail2Ban no instalado. ¿Instalar?" || { pause; return; }
        apt-get install -y fail2ban &>/dev/null &
        spinner $! "Instalando Fail2Ban"
    fi
    systemctl enable fail2ban &>/dev/null
    systemctl start fail2ban
    msg_ok "Fail2Ban activo."
    echo ""
    msg_info "Estado de jails:"
    fail2ban-client status 2>/dev/null || true
    echo ""
    msg_info "Últimos baneos (SSH):"
    fail2ban-client status sshd 2>/dev/null || msg_warn "Jail sshd no encontrado."
    log_action "Fail2Ban verificado/iniciado"
    pause
}

sec_open_ports() {
    msg_section "Puertos Abiertos"
    echo ""
    if command -v ss &>/dev/null; then
        echo -e "  ${BOLD}TCP${RESET} (LISTEN):"
        ss -tlnp 2>/dev/null | awk 'NR>1 {printf "  %-8s %-25s %s\n", $1, $4, $6}' | head -20
        echo ""
        echo -e "  ${BOLD}UDP${RESET}:"
        ss -ulnp 2>/dev/null | awk 'NR>1 {printf "  %-8s %-25s %s\n", $1, $4, $6}' | head -10
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | head -20
    else
        msg_warn "ss y netstat no disponibles."
    fi
    log_action "Escaneo de puertos abiertos locales"
    pause
}

sec_users_perms() {
    msg_section "Usuarios, Grupos y Permisos"
    echo ""
    echo -e "  ${BOLD}Usuarios con shell de login:${RESET}"
    awk -F: '$7 !~ /nologin|false/ {printf "  %-15s UID:%-6s %s\n", $1, $3, $7}' /etc/passwd | head -15
    echo ""
    echo -e "  ${BOLD}Usuarios en grupo sudo/wheel:${RESET}"
    getent group sudo wheel 2>/dev/null | while IFS=: read -r g _ _ members; do
        echo -e "  ${CYAN}$g${RESET}: $members"
    done
    echo ""
    echo -e "  ${BOLD}Archivos SUID sospechosos:${RESET}"
    find /usr /bin /sbin -perm -4000 -type f 2>/dev/null | head -10 | while read -r f; do
        echo -e "  ${YELLOW}$f${RESET}"
    done
    log_action "Revisión de usuarios, permisos y SUID"
    pause
}

sec_check_ssh_config() {
    msg_section "Configuración SSH"
    local sshd_cfg="/etc/ssh/sshd_config"
    if [[ ! -f "$sshd_cfg" ]]; then
        msg_warn "Archivo $sshd_cfg no encontrado."
        pause; return
    fi
    echo ""
    local checks=(
        "PermitRootLogin:no:Deshabilitar login root"
        "PasswordAuthentication:no:Forzar uso de claves"
        "X11Forwarding:no:Deshabilitar X11"
        "MaxAuthTries:3:Limitar intentos"
        "Protocol:2:Usar protocolo 2"
    )
    for check in "${checks[@]}"; do
        IFS=':' read -r param ideal label <<< "$check"
        local val
        val=$(grep -i "^${param}" "$sshd_cfg" 2>/dev/null | awk '{print $2}' | head -1)
        if [[ -z "$val" ]]; then
            echo -e "  ${YELLOW}${ICON_WARN}${RESET}  ${label}: ${DIM}(no definido)${RESET}"
        elif [[ "${val,,}" == "${ideal,,}" ]]; then
            echo -e "  ${GREEN}${ICON_OK}${RESET}  ${label}: ${GREEN}${val}${RESET}"
        else
            echo -e "  ${RED}${ICON_FAIL}${RESET}  ${label}: ${RED}${val}${RESET} ${DIM}(recomendado: ${ideal})${RESET}"
        fi
    done
    log_action "Revisión configuración sshd"
    pause
}

sec_disable_root_login() {
    msg_section "Deshabilitar Root Login SSH"
    _require_root || return
    local sshd_cfg="/etc/ssh/sshd_config"
    confirm "¿Modificar $sshd_cfg para deshabilitar login root?" || { msg_warn "Cancelado."; pause; return; }
    cp "$sshd_cfg" "${sshd_cfg}.bak.$(date +%Y%m%d)"
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$sshd_cfg"
    systemctl reload sshd 2>/dev/null || service ssh reload 2>/dev/null || true
    msg_ok "PermitRootLogin deshabilitado. Backup guardado."
    log_action "sshd: PermitRootLogin deshabilitado"
    pause
}

sec_suspicious_access() {
    msg_section "Accesos Sospechosos"
    echo ""
    echo -e "  ${BOLD}Últimos 20 logins:${RESET}"
    last -20 2>/dev/null | head -20
    echo ""
    echo -e "  ${BOLD}Intentos de acceso fallidos:${RESET}"
    if [[ -f /var/log/auth.log ]]; then
        grep -i "failed\|invalid" /var/log/auth.log 2>/dev/null | tail -15 | \
            awk '{print "  " $0}' || msg_warn "Sin errores recientes."
    else
        journalctl -u sshd --since "24 hours ago" 2>/dev/null | grep -i "failed\|invalid" | tail -15 || \
            msg_warn "No se pudo acceder al log de autenticación."
    fi
    log_action "Revisión de accesos sospechosos"
    pause
}

# =============================================================================
# SECCIÓN 10: MÓDULO MANTENIMIENTO Y MONITORIZACIÓN
# =============================================================================

menu_maintenance() {
    while true; do
        clear
        msg_section "${ICON_CPU}  Mantenimiento y Monitorización"
        echo ""
        echo -e "  ${CYAN}${BOLD}1${RESET}  Limpieza automática del sistema"
        echo -e "  ${CYAN}${BOLD}2${RESET}  Monitorización en tiempo real"
        echo -e "  ${CYAN}${BOLD}3${RESET}  Estado de servicios"
        echo -e "  ${CYAN}${BOLD}4${RESET}  Procesos activos (top 10 CPU)"
        echo -e "  ${CYAN}${BOLD}5${RESET}  Uso de disco (df / du)"
        echo -e "  ${CYAN}${BOLD}6${RESET}  Limpiar logs antiguos"
        echo -e "  ${CYAN}${BOLD}b${RESET}  Volver"
        echo ""
        read -rp "$(echo -e "  ${BOLD}Selección ${CYAN}»${RESET} ")" choice
        case "$choice" in
            1) maint_cleanup ;;
            2) maint_monitor_live ;;
            3) maint_services ;;
            4) maint_top_procs ;;
            5) maint_disk_usage ;;
            6) maint_clean_logs ;;
            b|B) return ;;
            *) msg_warn "Opción no válida" ; sleep 1 ;;
        esac
    done
}

maint_cleanup() {
    msg_section "Limpieza Automática del Sistema"
    _require_root || return
    local steps=("apt autoremove" "apt autoclean" "apt clean" "journalctl vacuum")
    for step in "${steps[@]}"; do
        case "$step" in
            "apt autoremove")  apt-get autoremove -y &>/dev/null & spinner $! "Eliminando paquetes no usados" ;;
            "apt autoclean")   apt-get autoclean -y &>/dev/null & spinner $! "Limpiando caché de apt" ;;
            "apt clean")       apt-get clean &>/dev/null & spinner $! "Limpiando paquetes descargados" ;;
            "journalctl vacuum") journalctl --vacuum-time=30d &>/dev/null & spinner $! "Rotando logs de journal" ;;
        esac
    done
    # Limpiar /tmp de archivos antiguos
    find /tmp -type f -atime +3 -delete 2>/dev/null || true
    msg_ok "Limpieza completada."
    log_action "Limpieza automática del sistema ejecutada"
    pause
}

maint_monitor_live() {
    msg_section "Monitorización en Tiempo Real"
    msg_info "Pulsa Ctrl+C para salir del monitor."
    sleep 1
    while true; do
        clear
        echo -e "${CYAN}${BOLD}  ── Monitor del Sistema ── $(date '+%H:%M:%S') ──${RESET}"
        echo ""

        # CPU
        local cpu
        cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
        local cpu_color="${GREEN}"; [[ "$cpu" -ge "$CPU_THRESHOLD" ]] && cpu_color="${RED}"
        printf "  ${ICON_CPU} CPU    ["; _draw_bar "$cpu" "$cpu_color"; printf "] ${cpu_color}${BOLD}%d%%${RESET}\n" "$cpu"

        # RAM
        local ram total_ram used_ram
        total_ram=$(free -m | awk '/^Mem/ {print $2}')
        used_ram=$(free -m | awk '/^Mem/ {print $3}')
        ram=$(free | awk '/^Mem/ {printf "%d", $3/$2*100}')
        local ram_color="${GREEN}"; [[ "$ram" -ge "$RAM_THRESHOLD" ]] && ram_color="${RED}"
        printf "  ${ICON_RAM} RAM    ["; _draw_bar "$ram" "$ram_color"; printf "] ${ram_color}${BOLD}%d%%${RESET} ${DIM}(%dMB / %dMB)${RESET}\n" "$ram" "$used_ram" "$total_ram"

        # Disco
        local disk
        disk=$(df / | awk 'NR==2 {print int($5)}')
        local disk_color="${GREEN}"; [[ "$disk" -ge "$DISK_THRESHOLD" ]] && disk_color="${RED}"
        printf "  ${ICON_DISK} Disco  ["; _draw_bar "$disk" "$disk_color"; printf "] ${disk_color}${BOLD}%d%%${RESET}\n" "$disk"

        echo ""
        echo -e "  ${BOLD}Red:${RESET}"
        ip -br a 2>/dev/null | awk '{printf "    %-12s %s\n", $1, $3}' | head -5

        echo ""
        echo -e "  ${BOLD}Top Procesos (CPU):${RESET}"
        ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=6 {printf "  %-25s CPU:%-5s MEM:%s\n", $11, $3, $4}'

        # Alertas
        echo ""
        [[ "$cpu" -ge "$CPU_THRESHOLD" ]] && echo -e "  ${RED}${BOLD}${ICON_WARN} ALERTA: CPU al ${cpu}%${RESET}"
        [[ "$ram" -ge "$RAM_THRESHOLD" ]] && echo -e "  ${RED}${BOLD}${ICON_WARN} ALERTA: RAM al ${ram}%${RESET}"
        [[ "$disk" -ge "$DISK_THRESHOLD" ]] && echo -e "  ${RED}${BOLD}${ICON_WARN} ALERTA: Disco al ${disk}%${RESET}"
        echo ""
        echo -e "  ${DIM}Actualización cada 3s · Ctrl+C para salir${RESET}"
        sleep 3
    done
}

_draw_bar() {
    local val=$1 color=$2 width=30
    local filled=$(( val * width / 100 ))
    local empty=$(( width - filled ))
    printf "${color}$(printf '█%.0s' $(seq 1 $filled))${RESET}${DIM}$(printf '░%.0s' $(seq 1 $empty))${RESET}"
}

maint_services() {
    msg_section "Estado de Servicios"
    local services=("ssh" "networking" "ufw" "fail2ban" "cron" "rsyslog" "systemd-journald")
    echo ""
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "  ${GREEN}${ICON_OK}${RESET}  ${BOLD}%-20s${RESET} ${GREEN}activo${RESET}" | xargs -I{} printf "  %s\n" ""; \
            printf "  ${GREEN}${ICON_OK}${RESET}  %-20s ${GREEN}activo${RESET}\n" "$svc"
        else
            printf "  ${RED}${ICON_FAIL}${RESET}  %-20s ${RED}inactivo${RESET}\n" "$svc"
        fi
    done
    pause
}

maint_top_procs() {
    msg_section "Procesos Activos (Top 10 CPU)"
    echo ""
    printf "  ${BOLD}%-8s %-25s %-8s %-8s${RESET}\n" "PID" "PROCESO" "CPU%" "MEM%"
    separator
    ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=11 {printf "  %-8s %-25s %-8s %-8s\n", $2, substr($11,1,25), $3, $4}'
    pause
}

maint_disk_usage() {
    msg_section "Uso de Disco"
    echo ""
    echo -e "  ${BOLD}Sistemas de ficheros montados:${RESET}"
    df -h 2>/dev/null | awk 'NR==1{printf "  %-25s %-8s %-8s %-8s %s\n", $1,$2,$3,$4,$5} NR>1{printf "  %-25s %-8s %-8s %-8s %s\n", $1,$2,$3,$4,$5}'
    echo ""
    echo -e "  ${BOLD}Directorios más pesados en /:${RESET}"
    du -sh /* 2>/dev/null | sort -rh | head -10 | awk '{printf "  %-10s %s\n", $1, $2}'
    pause
}

maint_clean_logs() {
    msg_section "Limpiar Logs Antiguos"
    _require_root || return
    local days
    read -rp "$(echo -e "  Eliminar logs con más de X días [30]: ")" days
    days="${days:-30}"
    echo ""
    msg_info "Buscando logs mayores de ${days} días..."
    find /var/log -type f -name "*.log" -mtime "+${days}" -print 2>/dev/null | while read -r f; do
        echo -e "  ${YELLOW}Eliminando:${RESET} $f"
        rm -f "$f"
    done
    journalctl --vacuum-time="${days}d" &>/dev/null && msg_ok "Journal purgado."
    msg_ok "Logs limpiados."
    log_action "Limpieza de logs mayores de ${days} días"
    pause
}

# =============================================================================
# SECCIÓN 11: CHECK RÁPIDO DEL SISTEMA
# =============================================================================

quick_check() {
    clear
    msg_section "${ICON_AUDIT}  Check Rápido del Sistema"
    echo ""
    local score=0 total=0

    _check_item() {
        local label="$1" ok="$2"
        total=$((total+1))
        if [[ "$ok" == "true" ]]; then
            score=$((score+1))
            printf "  ${GREEN}${ICON_OK}${RESET}  %-45s ${GREEN}OK${RESET}\n" "$label"
        else
            printf "  ${RED}${ICON_FAIL}${RESET}  %-45s ${RED}FALLO${RESET}\n" "$label"
        fi
    }

    # Uptime
    local uptime_val; uptime_val=$(uptime -p 2>/dev/null || echo "desconocido")
    echo -e "  ${DIM}Uptime: $uptime_val${RESET}"
    echo ""

    # Checks de seguridad
    local root_login; root_login=$(grep -i "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null | wc -l)
    _check_item "Root login SSH deshabilitado" "$([[ $root_login -gt 0 ]] && echo true || echo false)"

    local ufw_active; ufw_active=$(ufw status 2>/dev/null | grep -c "active" || echo 0)
    _check_item "Firewall UFW activo" "$([[ $ufw_active -gt 0 ]] && echo true || echo false)"

    local f2b; f2b=$(systemctl is-active fail2ban 2>/dev/null || echo inactive)
    _check_item "Fail2Ban activo" "$([[ $f2b == active ]] && echo true || echo false)"

    local ssh_ok; ssh_ok=$(systemctl is-active ssh sshd 2>/dev/null | grep -c "active" || echo 0)
    _check_item "Servicio SSH activo" "$([[ $ssh_ok -gt 0 ]] && echo true || echo false)"

    # Recursos
    local cpu; cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    _check_item "CPU dentro de umbral (<${CPU_THRESHOLD}%)" "$([[ $cpu -lt $CPU_THRESHOLD ]] && echo true || echo false)"

    local ram; ram=$(free | awk '/^Mem/ {printf "%d", $3/$2*100}')
    _check_item "RAM dentro de umbral (<${RAM_THRESHOLD}%)" "$([[ $ram -lt $RAM_THRESHOLD ]] && echo true || echo false)"

    local disk; disk=$(df / | awk 'NR==2 {print int($5)}')
    _check_item "Disco dentro de umbral (<${DISK_THRESHOLD}%)" "$([[ $disk -lt $DISK_THRESHOLD ]] && echo true || echo false)"

    # Actualizaciones pendientes
    local updates=0
    if command -v apt-get &>/dev/null; then
        updates=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || echo 0)
    fi
    _check_item "Sin actualizaciones pendientes" "$([[ $updates -eq 0 ]] && echo true || echo false)"
    [[ $updates -gt 0 ]] && echo -e "     ${DIM}($updates paquetes pendientes de actualización)${RESET}"

    echo ""
    separator
    local pct=$(( score * 100 / total ))
    local score_color="${GREEN}"
    [[ $pct -lt 60 ]] && score_color="${RED}"
    [[ $pct -ge 60 && $pct -lt 80 ]] && score_color="${YELLOW}"
    echo -e "  ${BOLD}Puntuación: ${score_color}${score}/${total} (${pct}%)${RESET}"
    echo ""
    [[ $pct -ge 80 ]] && msg_ok "Sistema en buen estado." || msg_warn "Hay aspectos a mejorar. Revisa los puntos marcados."
    log_action "Check rápido ejecutado: ${score}/${total} puntos"
    pause
}

# =============================================================================
# SECCIÓN 12: TAREAS PROGRAMADAS (CRON)
# =============================================================================

menu_cron() {
    while true; do
        clear
        msg_section "${ICON_CRON}  Tareas Programadas"
        echo ""
        echo -e "  ${CYAN}${BOLD}1${RESET}  Ver tareas SysCtrl activas"
        echo -e "  ${CYAN}${BOLD}2${RESET}  Añadir tarea programada"
        echo -e "  ${CYAN}${BOLD}3${RESET}  Eliminar tarea SysCtrl"
        echo -e "  ${CYAN}${BOLD}4${RESET}  Ver crontab completo"
        echo -e "  ${CYAN}${BOLD}b${RESET}  Volver"
        echo ""
        read -rp "$(echo -e "  ${BOLD}Selección ${CYAN}»${RESET} ")" choice
        case "$choice" in
            1) cron_list ;;
            2) cron_add ;;
            3) cron_remove ;;
            4) crontab -l 2>/dev/null | less; true ;;
            b|B) return ;;
            *) msg_warn "Opción no válida" ; sleep 1 ;;
        esac
    done
}

cron_list() {
    msg_section "Tareas SysCtrl Programadas"
    echo ""
    local tasks
    tasks=$(crontab -l 2>/dev/null | grep "$CRON_TAG" || echo "")
    if [[ -z "$tasks" ]]; then
        msg_warn "No hay tareas SysCtrl programadas aún."
    else
        echo "$tasks" | nl -ba | awk '{printf "  %s\n", $0}'
    fi
    pause
}

cron_add() {
    msg_section "Añadir Tarea Programada"
    echo ""
    echo -e "  ${DIM}Ejemplos de expresión cron:${RESET}"
    echo -e "  ${CYAN}0 3 * * *${RESET}   → cada día a las 3:00"
    echo -e "  ${CYAN}*/30 * * * *${RESET} → cada 30 minutos"
    echo -e "  ${CYAN}0 0 * * 0${RESET}   → cada domingo a medianoche"
    echo ""
    read -rp "$(echo -e "  Expresión cron: ")" cron_expr
    read -rp "$(echo -e "  Comando/script: ")" cron_cmd
    read -rp "$(echo -e "  Descripción: ")" cron_desc

    local entry="${cron_expr} ${cron_cmd} ${CRON_TAG} # ${cron_desc}"
    ( crontab -l 2>/dev/null; echo "$entry" ) | crontab -
    msg_ok "Tarea añadida al crontab."
    log_action "Cron añadido: $entry"
    pause
}

cron_remove() {
    msg_section "Eliminar Tarea SysCtrl"
    cron_list
    read -rp "$(echo -e "  Introduce parte del comando/descripción a eliminar: ")" pattern
    confirm "¿Eliminar todas las tareas que contienen '${pattern}'?" || { pause; return; }
    crontab -l 2>/dev/null | grep -v "$pattern" | crontab -
    msg_ok "Tarea(s) eliminada(s)."
    log_action "Cron eliminado con patrón: $pattern"
    pause
}

# =============================================================================
# SECCIÓN 13: DETECCIÓN DE RED LAN
# =============================================================================

scan_lan() {
    msg_section "${ICON_NET}  Detección de Red LAN"
    echo ""
    if ! command -v nmap &>/dev/null; then
        msg_warn "nmap no instalado."
        confirm "¿Instalar nmap?" && apt-get install -y nmap &>/dev/null && msg_ok "nmap instalado." || { pause; return; }
    fi

    local iface subnet
    iface=$(ip route | grep default | awk '{print $5}' | head -1)
    subnet=$(ip -o -f inet addr show "$iface" 2>/dev/null | awk '{print $4}' | head -1)

    if [[ -z "$subnet" ]]; then
        msg_error "No se pudo detectar la subred automáticamente."
        read -rp "  Introduce subred manualmente (ej: 192.168.1.0/24): " subnet
    fi

    msg_info "Escaneando red: ${subnet} (interfaz: ${iface})"
    echo ""

    nmap -sn "$subnet" 2>/dev/null | awk '
        /Nmap scan report/ {host=$NF; gsub(/[()]/,"",host)}
        /MAC Address/      {mac=$3; vendor=substr($0, index($0,$4))}
        /is up/            {printf "  %-20s  %-20s  %s\n", host, mac, vendor; mac=""; vendor=""}
    ' | head -30

    log_action "Escaneo de red LAN en $subnet"
    pause
}

# =============================================================================
# SECCIÓN 14: GESTIÓN DE PLUGINS
# =============================================================================

menu_plugins() {
    while true; do
        clear
        msg_section "${ICON_PLUGIN}  Gestión de Plugins"
        echo ""
        echo -e "  ${DIM}Directorio de plugins: ${PLUGINS_DIR}${RESET}"
        echo ""
        echo -e "  ${CYAN}${BOLD}1${RESET}  Listar plugins disponibles"
        echo -e "  ${CYAN}${BOLD}2${RESET}  Ejecutar plugin"
        echo -e "  ${CYAN}${BOLD}3${RESET}  Crear plugin de ejemplo"
        echo -e "  ${CYAN}${BOLD}b${RESET}  Volver"
        echo ""
        read -rp "$(echo -e "  ${BOLD}Selección ${CYAN}»${RESET} ")" choice
        case "$choice" in
            1) plugin_list ;;
            2) plugin_run ;;
            3) plugin_create_example ;;
            b|B) return ;;
            *) msg_warn "Opción no válida" ; sleep 1 ;;
        esac
    done
}

plugin_list() {
    msg_section "Plugins Disponibles"
    echo ""
    local count=0
    for plugin in "${PLUGINS_DIR}"/*.sh; do
        [[ -f "$plugin" ]] || continue
        local name desc
        name=$(basename "$plugin" .sh)
        desc=$(head -5 "$plugin" | grep "# DESC:" | sed 's/# DESC://' | xargs)
        printf "  ${CYAN}%-20s${RESET} %s\n" "$name" "${desc:-Sin descripción}"
        count=$((count+1))
    done
    [[ $count -eq 0 ]] && msg_warn "No hay plugins instalados."
    pause
}

plugin_run() {
    plugin_list
    read -rp "$(echo -e "  Nombre del plugin a ejecutar: ")" pname
    local pfile="${PLUGINS_DIR}/${pname}.sh"
    if [[ ! -f "$pfile" ]]; then
        msg_error "Plugin '${pname}' no encontrado."
        pause; return
    fi
    chmod +x "$pfile"
    msg_info "Ejecutando plugin: $pname"
    echo ""
    separator
    bash "$pfile"
    log_action "Plugin ejecutado: $pname"
    pause
}

plugin_create_example() {
    local pfile="${PLUGINS_DIR}/ejemplo_plugin.sh"
    cat > "$pfile" << 'PLUGIN'
#!/usr/bin/env bash
# DESC: Plugin de ejemplo - muestra info del sistema
# AUTOR: SysCtrl Pro

echo ""
echo "  === Plugin de Ejemplo ==="
echo "  Hostname: $(hostname)"
echo "  Kernel:   $(uname -r)"
echo "  Uptime:   $(uptime -p)"
echo ""
PLUGIN
    chmod +x "$pfile"
    msg_ok "Plugin de ejemplo creado en ${pfile}"
    log_action "Plugin de ejemplo creado"
    pause
}

# =============================================================================
# SECCIÓN 15: LOGS E HISTORIAL
# =============================================================================

menu_logs() {
    while true; do
        clear
        msg_section "${ICON_LOG}  Historial y Logs"
        echo ""
        echo -e "  ${CYAN}${BOLD}1${RESET}  Ver historial de acciones"
        echo -e "  ${CYAN}${BOLD}2${RESET}  Exportar informe de acciones"
        echo -e "  ${CYAN}${BOLD}3${RESET}  Ver logs del sistema (journal)"
        echo -e "  ${CYAN}${BOLD}4${RESET}  Limpiar historial SysCtrl"
        echo -e "  ${CYAN}${BOLD}b${RESET}  Volver"
        echo ""
        read -rp "$(echo -e "  ${BOLD}Selección ${CYAN}»${RESET} ")" choice
        case "$choice" in
            1) logs_view_actions ;;
            2) logs_export ;;
            3) journalctl -n 50 --no-pager 2>/dev/null | less; true ;;
            4) confirm "¿Limpiar historial?" && > "$ACTION_LOG" && msg_ok "Historial limpiado." ; pause ;;
            b|B) return ;;
            *) msg_warn "Opción no válida" ; sleep 1 ;;
        esac
    done
}

logs_view_actions() {
    msg_section "Historial de Acciones SysCtrl"
    echo ""
    if [[ ! -f "$ACTION_LOG" || ! -s "$ACTION_LOG" ]]; then
        msg_warn "No hay acciones registradas aún."
    else
        tail -50 "$ACTION_LOG" | awk '{
            if ($0 ~ /OK/) print "  \033[0;32m" $0 "\033[0m"
            else if ($0 ~ /ERROR/) print "  \033[0;31m" $0 "\033[0m"
            else print "  \033[0;37m" $0 "\033[0m"
        }'
    fi
    pause
}

logs_export() {
    msg_section "Exportar Informe"
    local report="${REPORTS_DIR}/report_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "=============================================="
        echo "  SysCtrl Pro - Informe del Sistema"
        echo "  Generado: $(date)"
        echo "  Host: $(hostname)  |  Usuario: $(whoami)"
        echo "=============================================="
        echo ""
        echo "--- SISTEMA ---"
        uname -a
        uptime
        echo ""
        echo "--- USO DE RECURSOS ---"
        free -h
        df -h
        echo ""
        echo "--- RED ---"
        ip -br a 2>/dev/null
        echo ""
        echo "--- SERVICIOS ---"
        systemctl list-units --type=service --state=running --no-pager 2>/dev/null | head -20
        echo ""
        echo "--- HISTORIAL DE ACCIONES SYSCTRL ---"
        cat "$ACTION_LOG" 2>/dev/null || echo "(vacío)"
    } > "$report"
    msg_ok "Informe guardado en: ${report}"
    log_action "Informe exportado: $report"
    pause
}

# =============================================================================
# SECCIÓN 16: CONFIGURACIÓN
# =============================================================================

menu_config() {
    while true; do
        clear
        msg_section "${ICON_GEAR}  Configuración"
        echo ""
        echo -e "  ${CYAN}${BOLD}1${RESET}  Editar configuración principal"
        echo -e "  ${CYAN}${BOLD}2${RESET}  Ver configuración actual"
        echo -e "  ${CYAN}${BOLD}3${RESET}  Cambiar perfil (básico/avanzado)"
        echo -e "  ${CYAN}${BOLD}4${RESET}  Verificar dependencias"
        echo -e "  ${CYAN}${BOLD}5${RESET}  Instalar dependencias faltantes"
        echo -e "  ${CYAN}${BOLD}b${RESET}  Volver"
        echo ""
        read -rp "$(echo -e "  ${BOLD}Selección ${CYAN}»${RESET} ")" choice
        case "$choice" in
            1) ${EDITOR:-nano} "$CONFIG_FILE" ; load_config ;;
            2) msg_section "Configuración Actual" ; echo ""; cat "$CONFIG_FILE" | grep -v "^#" | grep -v "^$" | awk '{print "  " $0}'; pause ;;
            3) config_switch_profile ;;
            4) config_check_deps ;;
            5) config_install_deps ;;
            b|B) return ;;
            *) msg_warn "Opción no válida" ; sleep 1 ;;
        esac
    done
}

config_switch_profile() {
    echo ""
    echo -e "  ${CYAN}1${RESET} Básico   ${CYAN}2${RESET} Avanzado"
    read -rp "  Selecciona perfil: " p
    local new_profile="advanced"
    [[ "$p" == "1" ]] && new_profile="basic"
    sed -i "s/^PROFILE=.*/PROFILE=\"$new_profile\"/" "$CONFIG_FILE"
    msg_ok "Perfil cambiado a: $new_profile"
    log_action "Perfil cambiado a: $new_profile"
    pause
}

config_check_deps() {
    msg_section "Verificación de Dependencias"
    echo ""
    local deps=("jq" "nmap" "ssh" "scp" "rsync" "ufw" "fail2ban-client" "ss" "netstat" "curl" "wget")
    for dep in "${deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            printf "  ${GREEN}${ICON_OK}${RESET}  %-20s ${GREEN}instalado${RESET}\n" "$dep"
        else
            printf "  ${YELLOW}${ICON_WARN}${RESET}  %-20s ${YELLOW}no instalado${RESET}\n" "$dep"
        fi
    done
    pause
}

config_install_deps() {
    msg_section "Instalación de Dependencias"
    _require_root || return
    local deps=("jq" "nmap" "openssh-client" "rsync" "ufw" "fail2ban" "net-tools" "curl" "wget")
    msg_info "Instalando dependencias..."
    apt-get install -y "${deps[@]}" 2>&1 | tail -3 &
    spinner $! "Instalando paquetes"
    msg_ok "Dependencias instaladas."
    log_action "Dependencias instaladas: ${deps[*]}"
    pause
}

# =============================================================================
# SECCIÓN 17: MODO AUDITORÍA
# =============================================================================

run_audit() {
    clear
    msg_section "${ICON_AUDIT}  Modo Auditoría de Seguridad"
    msg_info "Generando informe completo de seguridad..."
    echo ""

    local report="${REPORTS_DIR}/audit_$(date +%Y%m%d_%H%M%S).txt"
    local issues=0

    _audit_check() {
        local label="$1" result="$2" severity="${3:-INFO}"
        case "$severity" in
            OK)   printf "  ${GREEN}${ICON_OK}${RESET}  %-50s ${GREEN}[PASS]${RESET}\n" "$label" ;;
            WARN) printf "  ${YELLOW}${ICON_WARN}${RESET}  %-50s ${YELLOW}[WARN]${RESET}\n" "$label"; issues=$((issues+1)) ;;
            FAIL) printf "  ${RED}${ICON_FAIL}${RESET}  %-50s ${RED}[FAIL]${RESET}\n" "$label"; issues=$((issues+1)) ;;
            INFO) printf "  ${CYAN}${ICON_INFO}${RESET}  %-50s ${DIM}%s${RESET}\n" "$label" "$result" ;;
        esac
    }

    echo -e "  ${BOLD}── SISTEMA ──────────────────────────────────────${RESET}"
    _audit_check "Sistema operativo" "$(lsb_release -ds 2>/dev/null || uname -rs)" "INFO"
    _audit_check "Kernel" "$(uname -r)" "INFO"
    _audit_check "Uptime" "$(uptime -p)" "INFO"
    echo ""

    echo -e "  ${BOLD}── SSH ──────────────────────────────────────────${RESET}"
    local sshd="/etc/ssh/sshd_config"
    [[ -f "$sshd" ]] && {
        local v; v=$(grep -i "^PermitRootLogin" "$sshd" 2>/dev/null | awk '{print $2}')
        [[ "${v,,}" == "no" ]] && _audit_check "PermitRootLogin no" "" "OK" || _audit_check "PermitRootLogin debe ser 'no'" "$v" "FAIL"
        v=$(grep -i "^PasswordAuthentication" "$sshd" 2>/dev/null | awk '{print $2}')
        [[ "${v,,}" == "no" ]] && _audit_check "PasswordAuthentication no" "" "OK" || _audit_check "Considerar deshabilitar auth por contraseña" "$v" "WARN"
        v=$(grep -i "^Protocol" "$sshd" 2>/dev/null | awk '{print $2}')
        [[ "$v" == "2" || -z "$v" ]] && _audit_check "Protocolo SSH v2" "" "OK" || _audit_check "Usar Protocol 2" "$v" "FAIL"
    }
    echo ""

    echo -e "  ${BOLD}── FIREWALL ─────────────────────────────────────${RESET}"
    ufw status 2>/dev/null | grep -q "active" && _audit_check "UFW activo" "" "OK" || _audit_check "UFW no activo" "" "FAIL"
    echo ""

    echo -e "  ${BOLD}── FAIL2BAN ─────────────────────────────────────${RESET}"
    systemctl is-active --quiet fail2ban 2>/dev/null && _audit_check "Fail2Ban activo" "" "OK" || _audit_check "Fail2Ban no activo" "" "WARN"
    echo ""

    echo -e "  ${BOLD}── RECURSOS ─────────────────────────────────────${RESET}"
    local disk; disk=$(df / | awk 'NR==2 {print int($5)}')
    [[ $disk -lt $DISK_THRESHOLD ]] && _audit_check "Uso de disco OK (${disk}%)" "" "OK" || _audit_check "Disco al ${disk}% (umbral: ${DISK_THRESHOLD}%)" "" "WARN"
    local updates=0
    command -v apt-get &>/dev/null && updates=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || echo 0)
    [[ $updates -eq 0 ]] && _audit_check "Sin actualizaciones pendientes" "" "OK" || _audit_check "${updates} actualizaciones pendientes" "" "WARN"
    echo ""

    echo -e "  ${BOLD}── USUARIOS ─────────────────────────────────────${RESET}"
    local uid0_count; uid0_count=$(awk -F: '$3==0 {print $1}' /etc/passwd | grep -v "^root$" | wc -l)
    [[ $uid0_count -eq 0 ]] && _audit_check "Sin usuarios extra con UID 0" "" "OK" || _audit_check "${uid0_count} usuario(s) extra con UID 0!" "" "FAIL"
    echo ""

    separator
    local color="${GREEN}"
    [[ $issues -gt 0 && $issues -lt 4 ]] && color="${YELLOW}"
    [[ $issues -ge 4 ]] && color="${RED}"
    echo -e "  ${BOLD}Resultado: ${color}${issues} problemas encontrados${RESET}"
    echo ""

    # Guardar en archivo
    {
        echo "SysCtrl Pro - Auditoría de Seguridad"
        echo "Fecha: $(date)"
        echo "Host: $(hostname)"
        echo "---"
        echo "Problemas encontrados: $issues"
    } > "$report"

    msg_info "Informe guardado en: $report"
    log_action "Auditoría ejecutada: $issues problemas encontrados"
    pause
}

# =============================================================================
# SECCIÓN 18: UTILIDADES INTERNAS
# =============================================================================

_require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        msg_error "Esta acción requiere privilegios de root (sudo)."
        pause
        return 1
    fi
    return 0
}

exit_script() {
    echo ""
    echo -e "  ${DIM}Hasta pronto, $(whoami). SysCtrl Pro se ha cerrado correctamente.${RESET}"
    log_action "Sesión terminada"
    echo ""
    exit 0
}

# =============================================================================
# SECCIÓN 19: MANEJO DE ARGUMENTOS Y MODO SILENCIOSO/VERBOSE
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)   VERBOSE="true" ; shift ;;
            --quiet|-q)     QUIET="true"   ; shift ;;
            --check)        quick_check    ; exit 0 ;;
            --audit)        run_audit      ; exit 0 ;;
            --version)      echo "SysCtrl Pro v${VERSION}" ; exit 0 ;;
            --help|-h)      show_help      ; exit 0 ;;
            *)              msg_warn "Argumento desconocido: $1" ; shift ;;
        esac
    done
}

show_help() {
    cat << EOF

  SysCtrl Pro v${VERSION} - Panel de Control Bash para Debian/Linux

  Uso: $SCRIPT_NAME [opciones]

  Opciones:
    --verbose, -v     Modo verbose (más información)
    --quiet,   -q     Modo silencioso
    --check           Ejecutar check rápido y salir
    --audit           Ejecutar auditoría de seguridad y salir
    --version         Mostrar versión
    --help,    -h     Mostrar esta ayuda

  Sin opciones: inicia el menú interactivo.

EOF
}

# =============================================================================
# SECCIÓN 20: PUNTO DE ENTRADA PRINCIPAL
# =============================================================================

main() {
    # Inicializar directorios y configuración
    init_dirs
    load_config
    init_hosts_file

    # Parsear argumentos si los hay
    parse_args "$@"

    # Mostrar splash solo si no es modo quiet
    [[ "${QUIET:-false}" != "true" ]] && show_splash

    # Registrar inicio de sesión
    log_action "Sesión iniciada - SysCtrl Pro v${VERSION}"

    # Lanzar menú principal
    show_main_menu
}

# Trap para salida limpia
trap 'echo ""; echo -e "  ${DIM}Interrumpido. Saliendo...${RESET}"; tput cnorm 2>/dev/null; exit 1' INT TERM

# Ejecutar
main "$@"
