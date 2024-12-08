#!/bin/bash
set -e

if [ $# -ne 1 ]; then
	echo "Usage: $0 service" >&2
	exit 1
fi

if sudo systemctl is-active "$1" >/dev/null; then
	set -x
	sudo systemctl restart "$1"
fi
