#!/bin/bash
set -ex

has_command() {
	sudo which "$1" >/dev/null 2>&1
}

cd "$HOME"

mkdir -p "$(hostname)"

if has_command dpkg; then
	sudo dpkg -l > "$(hostname)/dpkg.txt"
	git add "$(hostname)/dpkg.txt"
fi
if has_command systemctl; then
	sudo systemctl > "$(hostname)/systemctl.txt"
	sudo systemctl status > "$(hostname)/systemctl-status.txt"
	sudo systemctl list-unit-files > "$(hostname)/systemctl-list-unit-files.txt"
	git add "$(hostname)/systemctl"{,-status,-list-unit-files}".txt"
fi
if has_command ps; then
	sudo ps aufx > "$(hostname)/ps.txt"
	git add "$(hostname)/ps.txt"
fi
if has_command lsb_release; then
	sudo lsb_release -a > "$(hostname)/lsb_release.txt"
	git add "$(hostname)/lsb_release.txt"
fi
if has_command uname; then
	sudo uname -a > "$(hostname)/uname.txt"
	git add "$(hostname)/uname.txt"
fi
if has_command hostnamectl; then
	sudo hostnamectl > "$(hostname)/hostnamectl.txt"
	git add "$(hostname)/hostnamectl.txt"
fi
if has_command docker; then
	sudo docker ps -a > "$(hostname)/docker-ps.txt"
	sudo docker images -a > "$(hostname)/docker-images.txt"
	git add "$(hostname)/docker-"{ps,images}".txt"
fi
sudo sh -c 'cat /etc/*-release' > "$(hostname)/release.txt"
git add "$(hostname)/release.txt"

cat /proc/cpuinfo > "$(hostname)/cpuinfo.txt"
cat /proc/meminfo > "$(hostname)/meminfo.txt"
git add "$(hostname)/"{cpuinfo,meminfo}".txt"

git commit -m "Add instance info for $(hostname)"
