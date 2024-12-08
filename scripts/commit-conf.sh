#!/bin/bash
set -e

execute() {
  echo "+ $*" >&2
  "$@"
}

if [ $# -ne 1 ]; then
  echo "Usage: $0 path" >&2
  exit 1
fi

cd "$HOME"

execute mkdir -p "$(hostname)"

execute cp  "$1" "$(hostname)/$(basename "$1")"
execute sudo cp "$1"{,.orig}
execute git add "$(hostname)/$(basename "$1")"
execute git commit -m "$(hostname): Add $1"
