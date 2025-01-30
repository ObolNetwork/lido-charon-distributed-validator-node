#!/bin/sh

if [ -z "$PROM_REMOTE_WRITE_TOKEN" ]
then
  echo "\$PROM_REMOTE_WRITE_TOKEN variable is empty" >&2
  exit 1
fi

sed "s|\$PROM_REMOTE_WRITE_TOKEN|${PROM_REMOTE_WRITE_TOKEN}|g" \
    /etc/prometheus/prometheus.yml.example > /etc/prometheus/prometheus.yml

/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml
