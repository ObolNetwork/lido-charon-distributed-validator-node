#!/bin/sh

if [ -z "$CHARON_LOKI_ADDRESSES" ]
then
  echo "\$CHARON_LOKI_ADDRESSES variable is empty"
fi

eval "echo \"$(cat /etc/promtail/config.yml.example)\"" > /etc/promtail/config.yml

# Start Promtail with the generated config
/usr/bin/promtail \
  -config.file=/etc/promtail/config.yml
