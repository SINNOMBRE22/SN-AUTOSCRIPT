<h1 align="center">SN · AUTOSCRIPT</h1>

<p align="center">
  <b>Administrador de VPS y protocolos — by SinNombre</b><br>
  <a href="https://t.me/SIN_NOMBRE22">t.me/SIN_NOMBRE22</a>
</p>

---

## ¿Qué es?

**SN-AUTOSCRIPT** instala y administra en tu VPS todo lo que necesitás para
vender y gestionar cuentas: usuarios SSH, V2Ray/XRAY y una buena cantidad de
protocolos de túnel, con panel propio, límites por usuario y licencia.

Pensado para revendedores: lo instalás en un VPS y administrás todo desde
`menu`, sin tocar configuraciones a mano.

---

## Instalación

En un VPS **limpio**, como `root`, pegá esto:

```bash
rm -rf /root/install.sh && wget --no-cache -O /root/install.sh https://raw.githubusercontent.com/SINNOMBRE22/SN-AUTOSCRIPT/main/install.sh && chmod +x /root/install.sh && /root/install.sh
```

El instalador te va a pedir:

1. **Key de licencia** (`SN-…`) — pedila a soporte.
2. **Dominio** con un registro **A** apuntando a la IP de tu VPS (para el certificado).
3. **Dominio NS** (opcional, solo si vas a usar SlowDNS).

Cuando termina, abrís el panel con:

```bash
menu
```

---

## Requisitos

- **Sistema:** Ubuntu 18.04 → 24.04 · Debian 10 → 13 (y derivados como Mint / Pop!_OS).
- **Arquitectura:** x86_64 (amd64) o aarch64 (arm64).
- **Acceso:** root.
- Un **dominio** apuntando al VPS (para el certificado TLS).

---

## Protocolos incluidos

| Servicio        | Puerto              |
|-----------------|---------------------|
| SSH             | 22                  |
| Dropbear        | 8022                |
| XRAY (443/TLS)  | VLESS-TCP · VLESS-WS · VMess-WS · Trojan-WS · VLESS-gRPC · XHTTP |
| XRAY (80)       | VLESS-TCP · VMess-WS · VLESS-WS (sin TLS) |
| SSL             | 443                 |
| SSL WS          | 443                 |
| WebSocket       | 80 / 8080           |
| BHTTP           | 8180                |
| HCR             | 8280                |
| BadVPN          | 7300                |
| UDP-Custom      | 1-65535 (UDP)       |
| Hysteria        | 36725 (+20000-39999)|
| ZivVPN          | 7538 (+5000-19999)  |
| Shadowsocks     | 8388                |
| SlowDNS         | 53                  |
| Check User      | 8000                |

---

## Panel (`menu`)

- **Usuarios SSH** — alta, baja, renovar, editar, límites de conexiones,
  velocidad y consumo, usuarios temporales y por horario.
- **V2Ray / XRAY** — alta/baja de clientes en todos los protocolos a la vez,
  links listos para copiar, stats de tráfico.
- **Herramientas** — info del sistema, cambiar dominio, hostname, respaldo,
  optimizar red (BBR), limpieza, test de velocidad y más.
- **Check User** — endpoint para que las apps muestren estado y conexiones.
- **Actualizar** — trae la última versión sin tocar tus usuarios ni tu licencia.

---

## Actualizar

Desde el panel: opción **101 (Actualizar)**. Baja lo último y reinstala solo
los protocolos que ya tenés activos — no toca usuarios, dominio, certificado
ni licencia.

---

## Soporte y ventas

<p align="center">
  💜 <b>Telegram:</b> <a href="https://t.me/SIN_NOMBRE22">@SIN_NOMBRE22</a>
</p>

<p align="center"><sub>© SinNombre — SN PLUS · AUTOSCRIPT</sub></p>
