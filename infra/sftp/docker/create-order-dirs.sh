#!/bin/bash
# Lo ejecuta el contenedor tih-sftp (atmoz/sftp) al arrancar, desde /etc/sftp.d/.
# Crea las carpetas de pedidos que usa sapi-sftp-orders-tih y se las da al usuario tihsftp.
mkdir -p /home/tihsftp/orders/pending /home/tihsftp/orders/processed /home/tihsftp/orders/error
chown -R 1001:users /home/tihsftp/orders
