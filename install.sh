#!/usr/bin/env bash
# =============================================================================
#  SysCtrl Pro - Instalador
# =============================================================================

set -euo pipefail

INSTALL_DIR="${HOME}/.sysctrl"
SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sysctrl.sh"
BIN_LINK="/usr/local/bin/sysctrl"

# Colores rápidos
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'; BOLD='\033[1m'

echo ""
echo -e "${CYAN}${BOLD}  SysCtrl Pro - Instalador v2.0.0${RESET}"
echo -e "  ─────────────────────────────────────"
echo ""

# Crear directorio de instalación
mkdir -p "${INSTALL_DIR}"/{config,data,logs,plugins,reports}
echo -e "  ${GREEN}✓${RESET} Directorios creados en ${INSTALL_DIR}"

# Copiar script principal
cp "$SCRIPT_SRC" "${INSTALL_DIR}/sysctrl.sh"
chmod +x "${INSTALL_DIR}/sysctrl.sh"
echo -e "  ${GREEN}✓${RESET} Script principal instalado"

# Crear enlace simbólico
if [[ "$(id -u)" -eq 0 ]]; then
    ln -sf "${INSTALL_DIR}/sysctrl.sh" "$BIN_LINK"
    echo -e "  ${GREEN}✓${RESET} Enlace creado: sysctrl → ${BIN_LINK}"
else
    # Añadir alias al .bashrc si no hay acceso a /usr/local/bin
    local_bin="${HOME}/.local/bin"
    mkdir -p "$local_bin"
    ln -sf "${INSTALL_DIR}/sysctrl.sh" "${local_bin}/sysctrl"
    grep -q "sysctrl" "${HOME}/.bashrc" 2>/dev/null || \
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "${HOME}/.bashrc"
    echo -e "  ${YELLOW}⚠${RESET}  Sin root: enlace creado en ${local_bin}/sysctrl"
    echo -e "     Recarga tu shell: ${CYAN}source ~/.bashrc${RESET}"
fi

# Verificar dependencias opcionales
echo ""
echo -e "  ${BOLD}Verificando dependencias:${RESET}"
for dep in jq nmap ssh rsync ufw fail2ban; do
    if command -v "$dep" &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} $dep"
    else
        echo -e "  ${YELLOW}○${RESET} $dep ${YELLOW}(opcional, instala con: apt install $dep)${RESET}"
    fi
done

echo ""
echo -e "  ${GREEN}${BOLD}Instalación completada.${RESET}"
echo -e "  Ejecuta: ${CYAN}${BOLD}sysctrl${RESET}  o  ${CYAN}${BOLD}bash ${INSTALL_DIR}/sysctrl.sh${RESET}"
echo ""
