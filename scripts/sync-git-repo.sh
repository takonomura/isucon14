#!/bin/bash
set -e

cd "$HOME"

execute() {
  echo "+ $*" >&2
  "$@"
}

if [ $# -ne 1 ]; then
  echo "Usage: $0 repo" >&2
  exit 1
fi

execute git init
execute git remote add origin "git@github.com:takonomura/$1.git"

execute git fetch
execute git reset origin/master
execute git branch -u origin/master

execute git status # Check difference file

echo ""
echo "Please check difference:"
echo "If you can omit any diff:"
echo "    git checkout ."
