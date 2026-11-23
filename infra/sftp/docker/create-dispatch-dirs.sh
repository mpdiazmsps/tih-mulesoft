#!/bin/bash
# Lo ejecuta poc-sftp (atmoz/sftp) al arrancar, desde /etc/sftp.d/.
# Crea las carpetas de logística: el estado de una remisión es la carpeta donde está (D12).
mkdir -p /home/pocsftp/despachos/pendientes /home/pocsftp/despachos/firmadas /home/pocsftp/despachos/rechazadas
chown -R 1001:users /home/pocsftp/despachos
chmod -R u+rwX,go+rX /home/pocsftp/despachos
