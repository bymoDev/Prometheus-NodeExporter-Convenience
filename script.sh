#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "creating user prome node_exporter"
useradd --no-create-home --shell /bin/false prome
useradd --no-create-home --shell /bin/false node_exporter

echo "creating /etc/prometheus /var/lib/prometheus"
mkdir /etc/prometheus
mkdir /var/lib/prometheus

wget https://github.com/prometheus/prometheus/releases/download/v2.0.0/prometheus-2.0.0.linux-amd64.tar.gz

tar xvf prometheus-2.0.0.linux-amd64.tar.gz

echo "copying prometheus, promtool"
cp prometheus-2.0.0.linux-amd64/prometheus /usr/local/bin/
cp prometheus-2.0.0.linux-amd64/promtool /usr/local/bin/
cp -r prometheus-2.0.0.linux-amd64/consoles /etc/prometheus
cp -r prometheus-2.0.0.linux-amd64/console_libraries /etc/prometheus

rm -r prometheus-2.0.0.linux-amd64/

chown prome:prome /usr/local/bin/prometheus
chown prome:prome /usr/local/bin/promtool

touch /etc/prometheus/prometheus.yml

cat << EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node_exporter_metrics'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9100']
EOF

touch /etc/systemd/system/prometheus.service

cat << EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

wget https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz

tar -xvf node_exporter-1.0.1.linux-amd64.tar.gz
mv node_exporter*/node_exporter /usr/local/bin
rm node_exporter-1.0.1.linux-amd64.tar.gz

touch /etc/systemd/system/node_exporter.service

cat << EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF


# services
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
