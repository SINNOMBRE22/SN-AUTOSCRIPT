# -*- coding: utf-8 -*-
# PDirect.py - Proxy HTTP a SSH

import socket
import threading
import select
import sys
import time
import argparse
import re

parser = argparse.ArgumentParser()
parser.add_argument("-p", "--port", required=True)
parser.add_argument("-l", "--local", required=True)
parser.add_argument("-r", "--response", default="200")
parser.add_argument("-t", "--texto", default="")
parser.add_argument("-c", "--xpass", default="")
parser.add_argument("-b", "--bind", default="127.0.0.1")
args = parser.parse_args()

LISTENING_PORT = int(args.port)
LOCAL_PORT     = int(args.local)
STATUS_RESP    = args.response
STATUS_TXT     = args.texto if args.texto else ""
XPASS_GLOBAL   = args.xpass

if STATUS_TXT == "":
    STATUS_TXT = "Connection Established" if STATUS_RESP != "101" else "SN Switching Protocols"

SERVER_NAME = "SinNombre"
XHTTP_PORT  = 10005   # inbound XHTTP de XRAY (127.0.0.1)
BUFLEN      = 16384  
TIMEOUT     = 120    

def make_response():
    if STATUS_RESP == '101':
        return (
            'HTTP/1.1 101 <strong>' + STATUS_TXT + '</strong>\r\n'
            'Server: ' + SERVER_NAME + '\r\n'
            'Connection: Upgrade\r\n'
            'Upgrade: websocket\r\n'
            'Content-length: 0\r\n'
            '\r\n'
            'HTTP/1.1 200 Connection established\r\n'
            'Server: ' + SERVER_NAME + '\r\n'
            '\r\n'
        )
    return (
        'HTTP/1.1 200 <strong>' + STATUS_TXT + '</strong>\r\n'
        'Server: ' + SERVER_NAME + '\r\n'
        'Connection: keep-alive\r\n'
        'Content-length: 0\r\n'
        '\r\n'
        'HTTP/1.1 200 Connection established\r\n'
        'Server: ' + SERVER_NAME + '\r\n'
        '\r\n'
    )

RESPONSE = make_response()

def find_header(data, header_name):
    try:
        text = data.decode('utf-8', errors='ignore') if isinstance(data, bytes) else data
        for line in text.split('\r\n'):
            if line.lower().startswith(header_name.lower() + ':'):
                return line.split(':', 1)[1].strip()
    except Exception:
        pass
    return None

def es_xhttp(data):
    # XHTTP por HTTP/1.1 (puerto 80, o 443 sin h2) pide /xhttp/<sesion>/...
    # y el fallback de XRAY solo compara el path exacto, asi que llega
    # aca. Se reconoce por la primera linea: "METODO /xhttp... HTTP/1.x".
    try:
        partes = data.split(b'\r\n', 1)[0].split(b' ')
        if len(partes) >= 3 and partes[2].startswith(b'HTTP/'):
            ruta = partes[1]
            return ruta == b'/xhttp' or ruta.startswith(b'/xhttp/') or ruta.startswith(b'/xhttp?')
    except Exception:
        pass
    return False

def log(msg):
    sys.stderr.write("[PDirect] " + msg + "\n")
    sys.stderr.flush()

def tune_socket(s):
    try:
        s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
    except Exception:
        pass
    try:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 262144)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 262144)
    except Exception:
        pass

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host    = host
        self.port    = port
        self.daemon  = True

    def run(self):
        self.soc = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, self.port))
        self.soc.listen(500)
        self.running = True
        log("Servidor iniciado en {}:{}".format(self.host, self.port))
        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    tune_socket(c)
                    log("Nueva conexion desde {}".format(addr))
                except socket.timeout:
                    continue
                except Exception as e:
                    log("Error aceptando conexión: {}".format(e))
                    continue

                ConnectionHandler(c, addr).start()
        finally:
            self.running = False
            self.soc.close()

class ConnectionHandler(threading.Thread):
    def __init__(self, client, addr):
        threading.Thread.__init__(self)
        self.client = client
        self.addr   = addr
        self.target = None
        self.daemon = True

    def close(self):
        try:
            self.client.close()
        except Exception:
            pass
        try:
            if self.target:
                self.target.close()
        except Exception:
            pass

    def connect_local(self, port=None):
        port = port or LOCAL_PORT
        self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        tune_socket(self.target)
        try:
            self.target.connect(('127.0.0.1', port))
            return True
        except Exception as e:
            log("Error conectando a local {}: {}".format(port, e))
            return False

    def run(self):
        try:
            data = self.client.recv(BUFLEN)
            if not data:
                log("Sin datos iniciales, cerrando")
                return

            # SSH crudo (SSL directo: el cliente manda "SSH-2.0-..." sin
            # payload). XRAY ahora manda aca TODO lo que no coincide con
            # un path de XRAY, asi que el bridge tiene que dejarlo pasar
            # intacto: sin respuesta HTTP y sin descartar el paquete.
            if es_xhttp(data):
                if self.connect_local(XHTTP_PORT):
                    self.target.sendall(data)
                    self.tunnel()
                return

            if data.startswith(b'SSH-'):
                if self.connect_local():
                    self.target.sendall(data)
                    self.tunnel()
                return

            if XPASS_GLOBAL:
                xpass_hdr = find_header(data, 'X-Pass')
                if xpass_hdr != XPASS_GLOBAL:
                    self.client.sendall(b'HTTP/1.1 403 Forbidden\r\n\r\n')
                    log("403 - X-Pass incorrecto")
                    return

            # Payload (cualquier metodo/path, con o sin TLS): se responde
            # 101 y se descarta el payload, igual que siempre.
            resp = RESPONSE
            if isinstance(resp, str):
                resp = resp.encode('utf-8')
            self.client.sendall(resp)

            if self.connect_local():
                # Si el cliente mando payload + "SSH-2.0-..." en el mismo
                # paquete, se reenvia la parte SSH en vez de perderla.
                pos = data.find(b'SSH-')
                if pos > 0:
                    self.target.sendall(data[pos:])
                    self.tunnel(True)
                else:
                    self.tunnel(False)

        except Exception as e:
            log("Excepcion en conexion: {}".format(str(e)))
        finally:
            self.close()

    def tunnel(self, ssh_ok=True):
        # ssh_ok=False: todavia no llego el "SSH-" del cliente. Lo que
        # llegue antes es payload HTTP partido en varios paquetes (por
        # el puerto 80 el 2do request llega aparte) y se descarta; si
        # pasara a sshd contestaria "Invalid SSH identification string".
        socs = [self.client, self.target]
        idle_time = 0

        while True:
            try:
                recv, _, err = select.select(socs, [], socs, 3)
            except select.error:
                continue
            except Exception:
                break

            if err:
                break

            if not recv:
                idle_time += 3
                if idle_time >= TIMEOUT:
                    log("Timeout alcanzado, cerrando túnel inactivo")
                    break
                continue

            idle_time = 0

            for s in recv:
                try:
                    buf = s.recv(BUFLEN)
                    if not buf:
                        return

                    if s is self.target:
                        self.client.sendall(buf)
                    else:
                        if not ssh_ok:
                            pos = buf.find(b'SSH-')
                            if pos < 0:
                                continue
                            buf = buf[pos:]
                            ssh_ok = True
                        self.target.sendall(buf)
                except (ConnectionResetError, BrokenPipeError):
                    return
                except Exception as e:
                    log("Error de transferencia en buffer: {}".format(str(e)))
                    return

def main():
    print("\n:------- PDirect SNPLUS -------:")
    print("Puerto escucha : {}".format(LISTENING_PORT))
    print("Redirige a     : 127.0.0.1:{}".format(LOCAL_PORT))
    print("Respuesta HTTP : {} {}".format(STATUS_RESP, STATUS_TXT))
    if XPASS_GLOBAL:
        print("X-Pass global  : requerido")
    else:
        print("X-Pass global  : no requerido")
    print(":------------------------------:\n")

    server = Server(args.bind, LISTENING_PORT)
    server.start()
    try:
        while True:
            time.sleep(2)
    except KeyboardInterrupt:
        sys.exit(0)

if __name__ == '__main__':
    main()
