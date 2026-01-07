#!/bin/sh

if [ -z "$SERVICE_OWNER" ]
then
  if [ -f /opt/charon/.charon/cluster-lock.json ]; then
    export SERVICE_OWNER=$(cat /opt/charon/.charon/cluster-lock.json | jq -r '.lock_hash[2:9]')
  else
    export SERVICE_OWNER="unknown"
  fi
fi

if [ -z "$PROM_REMOTE_WRITE_TOKEN" ]
then
  echo "\$PROM_REMOTE_WRITE_TOKEN variable is empty" >&2
  exit 1
fi

sed -e "s|\$PROM_REMOTE_WRITE_TOKEN|${PROM_REMOTE_WRITE_TOKEN}|g" \
    -e "s|\$SERVICE_OWNER|${SERVICE_OWNER}|g" \
    -e "s|\$ALERT_DISCORD_IDS|${ALERT_DISCORD_IDS}|g" \
    -e "s|\$OPERATOR_PROMETHEUS_LABEL|${OPERATOR_PROMETHEUS_LABEL}|g" \
    /etc/prometheus/prometheus.yml.example > /etc/prometheus/prometheus.yml

/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml
