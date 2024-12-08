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

echo "Buiilding .gitignore"
curl -sSL https://www.gitignore.io/api/linux,vim > .gitignore
cat << 'EOF' >> .gitignore


/.*_history
/.*_logout
/.ssh
/.gitconfig
/logs
/.viminfo
/.sudo_as_admin_successful
/.lesshst
/.gem
/.bundle
/.cache
/.local
/.xbuild
/.deno
/.cargo
/.composer
/.cpanm
/.npm
/.perl-cpm
/.rustup
/.cmake
/.config

*.log
*.prof

node_modules
EOF

for f in "xbuild" "local" "go/pkg" "tmp"; do
  if [ -e "$f" ]; then
    echo "Ignore $f"
    echo "/$f" >> .gitignore
  fi
done

execute git add .
execute git status

echo ""
echo "Please check unexpected files has not been added."
echo "And execute following command:"
echo '    git commit -m '"'"'Add $HOME'"'"
echo "    git push -u origin master"
