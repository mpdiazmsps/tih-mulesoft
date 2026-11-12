"""Prueba de humo del SFTP local (Rebex): crear, listar, leer, mover y borrar.

Uso (desde infra/sftp, con el venv local):
    .venv\\Scripts\\python.exe smoke-test-sftp.py

Lee host, puerto, usuario y contrasena de credentials.local (mismo directorio).
"""
import io
import pathlib
import sys

import paramiko

HERE = pathlib.Path(__file__).resolve().parent
PENDING = "/orders/pending"
PROCESSED = "/orders/processed"


def load_credentials():
    values = {}
    for line in (HERE / "credentials.local").read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def main():
    cfg = load_credentials()
    transport = paramiko.Transport((cfg["SFTP_HOST"], int(cfg["SFTP_PORT"])))
    transport.connect(username=cfg["SFTP_USER"], password=cfg["SFTP_PASSWORD"])
    sftp = paramiko.SFTPClient.from_transport(transport)
    name = "smoke-test_00000000.csv"
    try:
        print("raiz:", sftp.listdir("/"))
        print("orders:", sftp.listdir("/orders"))

        # Crear (patron .tmp + rename, igual que hara sapi-sftp-orders)
        sftp.putfo(io.BytesIO(b"item,qty\nabc,1\n"), f"{PENDING}/{name}.tmp")
        sftp.rename(f"{PENDING}/{name}.tmp", f"{PENDING}/{name}")
        print("creado y renombrado:", name)

        # Listar
        pending = sftp.listdir(PENDING)
        print("pending:", pending)
        assert name in pending, "el archivo no aparece en /orders/pending"

        # Leer
        with sftp.open(f"{PENDING}/{name}") as fh:
            content = fh.read().decode("utf-8")
        assert content.startswith("item,qty"), "contenido inesperado"
        print("lectura OK:", repr(content))

        # Mover
        sftp.rename(f"{PENDING}/{name}", f"{PROCESSED}/{name}")
        assert name not in sftp.listdir(PENDING)
        assert name in sftp.listdir(PROCESSED)
        print("movido a /orders/processed")
    finally:
        try:
            sftp.remove(f"{PROCESSED}/{name}")
            print("limpieza OK")
        except OSError:
            pass
        sftp.close()
        transport.close()
    print("SFTP smoke test: OK")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print("SFTP smoke test: FALLO ->", exc)
        sys.exit(1)
