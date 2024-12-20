#!/bin/bash
set -e

cd "$HOME"
mkdir -p logs
TIMESTAMP=$(date +%H%M%S)

for f in /var/log/nginx/{access,error}.log /var/log/mysql/mysql-slow.log; do
  if sudo test -f "$f"; then
    output="logs/$(basename "$f")"
    output="${output/%.log/.$TIMESTAMP.log}"
    echo mv "$f" "$output"
    sudo mv "$f" "$output"
    sudo chown $USER:$USER "$output"
    gzip "$output"
  fi
done
