#!/bin/bash
set -e

cd "$HOME"

if [ -f /etc/nginx/nginx.conf ]; then
  scripts/commit-conf.sh /etc/nginx/nginx.conf
fi
if [ -f /etc/h2o/h2o.conf ]; then
  scripts/commit-conf.sh /etc/h2o/h2o.conf
fi
if [ -f /etc/mysql/mysql.conf.d/mysqld.cnf ]; then
  scripts/commit-conf.sh /etc/mysql/mysql.conf.d/mysqld.cnf
elif [ -f /etc/my.cnf ]; then
  scripts/commit-conf.sh /etc/my.cnf
fi
for f in /etc/systemd/system/isu*.service; do
  scripts/commit-conf.sh "$f"
done
