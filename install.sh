
R='\033[1;31m'; G='\033[0;32m'; Vd='\033[1;32m'; Y='\033[1;33m'; Am='\033[1;33m'
C='\033[38;2;0;229;255m'; W='\033[1;37m'; N='\033[0m'; D='\033[2m'
M='\033[1;38;2;138;43;226m'; Mf='\033[38;2;138;43;226m'
LINEA50="──────────────────────────────────────────────"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="/etc/SN-AUTOSCRIPT"
LOCK_FILE="/tmp/sn_autoscript_install.lock"
LOG_FILE="/var/log/sn_autoscript_install.log"
LIC_DIR="/etc/.sn"
RAW_BASE="https://raw.githubusercontent.com/SINNOMBRE22/SN-AUTOSCRIPT/main"

export DEBIAN_FRONTEND=noninteractive
export UCF_FORCE_CONFFOLD=1
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
APT_OPTS=(-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
          -o APT::Get::AllowUnauthenticated=true -o DPkg::Lock::Timeout=60)

: > "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/sn_autoscript_install.log"
log()  { echo "[$(date '+%F %T')] $*" >> "$LOG_FILE" 2>/dev/null; }
ok()   { printf "    ${Vd}✔${N} %b\n" "$1"; log "OK: $1"; }
warn() { printf "    ${Am}!${N} %b\n" "$1"; log "AVISO: $1"; }
info() { printf "    ${C}•${N} %b\n" "$1"; log "INFO: $1"; }
die() {
    printf "\033[?25h\n${R}${LINEA50}${N}\n${R}  ERROR${N}\n${R}${LINEA50}${N}\n  $1\n"
    [[ -n "$2" ]] && printf "  ${D}$2${N}\n"
    printf "\n  ${D}Log: %s${N}\n" "$LOG_FILE"
    rm -f "$LOCK_FILE"; exit 1
}
cleanup() { printf "\033[?25h"; rm -f "$LOCK_FILE"; }
trap cleanup EXIT
trap 'printf "\033[?25h\n"; echo -e "${Y}Instalacion cancelada.${N}"; rm -f "$LOCK_FILE"; exit 130' INT TERM

spinner() {
    local msg="$1"; shift
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'); local idx=0
    printf "\033[?25l"
    ( "$@" ) >> "$LOG_FILE" 2>&1 < /dev/null &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r    %s %s" "$msg" "${frames[$idx]}"; idx=$(( (idx+1) % 10 )); sleep 0.1
    done
    wait "$pid"; local rc=$?
    if [[ $rc -eq 0 ]]; then printf "\r\033[K    ${Vd}✔${N} %s\n" "$msg"
    else printf "\r\033[K    ${R}✗${N} %s\n" "$msg"; fi
    printf "\033[?25h"; return $rc
}

clear
if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
    figlet -f slant 'SN - PLUS' | lolcat
else
    echo -e "${W}   SN PLUS · AUTOSCRIPT${N}"
fi
echo -e "  ${Mf}[-]${LINEA50}${N}"
echo -e "           ${W}SN PLUS v2.0.7${N} ${D}—${N} ${C}@SIN_NOMBRE22${N}"
echo -e "           ${D}Instalador de SN-AUTOSCRIPT${N}"
echo -e "  ${Mf}[-]${LINEA50}${N}\n"

[[ "$(id -u)" -ne 0 ]] && { echo -e "${R}Ejecuta con:${N} sudo bash install.sh"; exit 1; }
if [[ -f "$LOCK_FILE" ]]; then
    old_pid=$(cat "$LOCK_FILE" 2>/dev/null)
    [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null && die "Ya hay una instalacion en curso (PID $old_pid)."
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"

DISTRO_ID=""; [[ -f /etc/os-release ]] && { . /etc/os-release; DISTRO_ID="${ID:-unknown}"; }
case "$DISTRO_ID" in
    ubuntu|debian) ok "Sistema soportado: $PRETTY_NAME" ;;
    *) warn "Distro no probada, se continua igual." ;;
esac
[[ "$(uname -m)" == "x86_64" || "$(uname -m)" == "aarch64" ]] || die "Arquitectura no soportada."

echo -e "  ${Mf}[-]${LINEA50}${N}"
read -rp "  $(echo -e "${W}Key de licencia SN-:${N} ")" LIC_KEY
while [[ ! "$LIC_KEY" =~ ^SN-[A-Za-z0-9]{10,}$ ]]; do
    read -rp "  $(echo -e "${R}Formato invalido, de nuevo (SN-...):${N} ")" LIC_KEY
done
echo -e "  ${Mf}[-]${LINEA50}${N}\n"

spinner "Preparando el sistema" apt-get update "${APT_OPTS[@]}" -y
spinner "Instalando dependencias base" apt-get install "${APT_OPTS[@]}" -y \
    curl wget unzip tar gnupg lsb-release ca-certificates jq socat rsync \
    build-essential g++ cmake git libcurl4-openssl-dev uuid-runtime cron figlet \
    || die "Fallaron las dependencias base."

if ! command -v lolcat >/dev/null 2>&1; then
    spinner "Preparando el banner" bash -c '
        apt-get install -y lolcat || { apt-get install -y ruby-full && gem install lolcat; }
    '
fi
command -v qrencode >/dev/null 2>&1 || spinner "Preparando extras" apt-get install "${APT_OPTS[@]}" -y qrencode
spinner "Habilitando tareas programadas" bash -c "systemctl enable cron && systemctl start cron"

mkdir -p "$LIC_DIR"; chmod 700 "$LIC_DIR"
echo "$LIC_KEY" > "$LIC_DIR/lic"; chmod 600 "$LIC_DIR/lic"

mkdir -p "$DEPLOY_DIR/Sistema/global"
if [[ -x "$SRC_DIR/Sistema/Lic" ]]; then
    spinner "Preparando el validador de licencia" bash -c "
        cp -f '$SRC_DIR/Sistema/Lic' /usr/local/bin/Lic
        [[ -f '$SRC_DIR/Sistema/global/libsn_global.so' ]] && cp -f '$SRC_DIR/Sistema/global/libsn_global.so' '$DEPLOY_DIR/Sistema/global/libsn_global.so'
        chmod 700 /usr/local/bin/Lic
    "
elif [[ -f "$SRC_DIR/Sistema/Lic.cpp" ]]; then
    spinner "Preparando el validador de licencia" bash -c "
        g++ -std=c++17 -O2 -s -o /usr/local/bin/Lic '$SRC_DIR/Sistema/Lic.cpp' \
            -I'$SRC_DIR/Sistema' -L'$SRC_DIR/Sistema/global' \
            -Wl,-rpath='$SRC_DIR/Sistema/global' -Wl,-rpath='$DEPLOY_DIR/Sistema/global' \
            -lsn_global -lcurl && chmod 700 /usr/local/bin/Lic
    "
else
    spinner "Preparando el validador de licencia" bash -c "
        curl -fsSL -o /usr/local/bin/Lic '$RAW_BASE/Sistema/Lic' &&
        curl -fsSL -o '$DEPLOY_DIR/Sistema/global/libsn_global.so' '$RAW_BASE/Sistema/global/libsn_global.so' &&
        chmod 700 /usr/local/bin/Lic
    "
fi
[[ -x /usr/local/bin/Lic ]] || die "No se pudo preparar el validador de licencia."

/usr/local/bin/Lic --activate --quiet >> "$LOG_FILE" 2>&1
LIC_RC=$?
if [[ $LIC_RC -ne 0 ]]; then
    die "La licencia no se pudo activar." "Verifica la key con soporte antes de reintentar."
fi
ok "Licencia activada"

echo -e "  ${Mf}[-]${LINEA50}${N}"
read -rp "  $(echo -e "${W}Dominio A (certificado):${N} ")" DOMAIN
while [[ -z "$DOMAIN" ]]; do read -rp "  $(echo -e "${R}Obligatorio:${N} ")" DOMAIN; done
read -rp "  $(echo -e "${W}Dominio NS (SlowDNS, opcional):${N} ")" DOMAIN_NS
read -rp "  $(echo -e "${W}Reseller [SinNombre]:${N} ")" RESELLER
RESELLER="${RESELLER:-SinNombre}"
echo -e "  ${Mf}[-]${LINEA50}${N}\n"

info "Verificando DNS de $DOMAIN..."
VPS_IP="$(curl -fsS --max-time 4 https://api.ipify.org || curl -fsS --max-time 4 https://ifconfig.me)"
DOMAIN_IP="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk '{print $1; exit}')"
if [[ -z "$DOMAIN_IP" ]]; then
    warn "No se pudo resolver un registro A para $DOMAIN."
    read -rp "  $(echo -e "${W}Continuar de todas formas? (s/n):${N} ")" CONT_DNS
    [[ "$CONT_DNS" != "s" && "$CONT_DNS" != "S" ]] && die "Instalacion detenida." "Corregi el DNS de $DOMAIN y volve a correr install.sh."
elif [[ -n "$VPS_IP" && "$DOMAIN_IP" != "$VPS_IP" ]]; then
    warn "$DOMAIN resuelve a $DOMAIN_IP pero la IP de este VPS es $VPS_IP."
    read -rp "  $(echo -e "${W}Continuar de todas formas? (s/n):${N} ")" CONT_DNS
    [[ "$CONT_DNS" != "s" && "$CONT_DNS" != "S" ]] && die "Instalacion detenida." "Corregi el DNS de $DOMAIN y volve a correr install.sh."
else
    ok "$DOMAIN -> $DOMAIN_IP"
fi

mkdir -p "$DEPLOY_DIR/certs"
if [[ ! -s "$HOME/.acme.sh/acme.sh" ]]; then
    spinner "Preparando el certificado" bash -c "curl -fsSL https://get.acme.sh | sh -s email=admin@$DOMAIN" \
        || die "No se pudo preparar el certificado."
fi
ACME="$HOME/.acme.sh/acme.sh"
"$ACME" --set-default-ca --server letsencrypt >>"$LOG_FILE" 2>&1
spinner "Emitiendo certificado para $DOMAIN" "$ACME" --issue -d "$DOMAIN" --standalone -k ec-256 --force
[[ $? -ne 0 ]] && die "No se pudo emitir el certificado." "Verifica el DNS de $DOMAIN y que el puerto 80 este libre."
spinner "Instalando certificado" "$ACME" --install-cert -d "$DOMAIN" --ecc \
    --fullchain-file "$DEPLOY_DIR/certs/fullchain.pem" \
    --key-file        "$DEPLOY_DIR/certs/privkey.pem" \
    --reloadcmd       "systemctl list-unit-files xray.service >/dev/null 2>&1 && systemctl reload-or-restart xray 2>/dev/null; true"
chmod 644 "$DEPLOY_DIR/certs/fullchain.pem" "$DEPLOY_DIR/certs/privkey.pem"

mkdir -p "$DEPLOY_DIR"/usuarios/xray

if [[ -f "$SRC_DIR/Sistema/protocolos_setup.cpp" ]]; then
    cd "$SRC_DIR"
    chmod +x build.sh 2>/dev/null
    spinner "Preparando SN-AUTOSCRIPT" ./build.sh || die "Fallo la preparacion." "Revisa $LOG_FILE"
    spinner "Guardando configuracion" rsync -a --exclude='*.cpp' --exclude='*.h' \
        --exclude='.git' --exclude='build.sh' --exclude='distribuir.sh' \
        --exclude='domain.conf' --exclude='domain_ns.conf' --exclude='reseller.conf' \
        --exclude='version' --exclude='usuarios' \
        "$SRC_DIR"/ "$DEPLOY_DIR"/
elif [[ -x "$SRC_DIR/menu" ]]; then
    spinner "Guardando configuracion" rsync -a --exclude='.git' \
        --exclude='domain.conf' --exclude='domain_ns.conf' --exclude='reseller.conf' \
        --exclude='version' --exclude='usuarios' \
        "$SRC_DIR"/ "$DEPLOY_DIR"/
else
    spinner "Preparando SN-AUTOSCRIPT" bash -c "
        curl -fsSL -o '$DEPLOY_DIR/install' '$RAW_BASE/install' && chmod 700 '$DEPLOY_DIR/install'
    " || die "No se pudo preparar SN-AUTOSCRIPT." "Revisa la conexion a internet."
fi
[[ -x "$DEPLOY_DIR/install" ]] || die "Falta el instalador principal." "Revisa $LOG_FILE"

echo "$DOMAIN"    > "$DEPLOY_DIR/domain.conf"
echo "$DOMAIN_NS" > "$DEPLOY_DIR/domain_ns.conf"
echo "$RESELLER"  > "$DEPLOY_DIR/reseller.conf"
echo "1.0"         > "$DEPLOY_DIR/version"
touch "$DEPLOY_DIR/usuarios/ssh.list"

ln -sf "$DEPLOY_DIR/menu"                      /usr/local/bin/menu
ln -sf "$DEPLOY_DIR/Sistema/protocolos_setup"  /usr/local/bin/protocolos_setup
chmod 700 /usr/local/bin/Lic 2>/dev/null

cat > /etc/systemd/system/Lic-check.service <<'EOF'
[Unit]
Description=SN PLUS - Revalidacion de licencia
[Service]
Type=oneshot
ExecStart=/usr/local/bin/Lic --quiet
EOF
cat > /etc/systemd/system/Lic-check.timer <<'EOF'
[Unit]
Description=SN PLUS - Timer de revalidacion de licencia (5 min)
[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=Lic-check.service
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now Lic-check.timer >>"$LOG_FILE" 2>&1

echo -e "\n${Mf}[-]${LINEA50}${N}"
echo -e "${W}  Instalando protocolos (esto tarda varios minutos)...${N}"
echo -e "${Mf}[-]${LINEA50}${N}\n"
"$DEPLOY_DIR/install"
INSTALL_RC=$?

ln -sf "$DEPLOY_DIR/menu"                      /usr/local/bin/menu
ln -sf "$DEPLOY_DIR/Sistema/protocolos_setup"  /usr/local/bin/protocolos_setup

rm -f "$LOCK_FILE"
[[ $INSTALL_RC -ne 0 ]] && warn "Algun protocolo quedo con aviso — corre 'menu' (opcion 4) para ver el detalle y reintentar por partes."
exit 0
