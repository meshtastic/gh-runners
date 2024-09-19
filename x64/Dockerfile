FROM ubuntu:22.04
MAINTAINER Jonathan Bennett
RUN <<EOF
useradd ubuntu -m -s /bin/bash
usermod -a -G sudo ubuntu
apt update
apt upgrade -y
apt install curl pip git python3-venv pkg-config libicu-dev sudo podman zip -y
sed -i /etc/sudoers -re 's/^%sudo.*/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g'
ln -s /usr/bin/podman /usr/bin/docker
EOF

WORKDIR /home/ubuntu
USER ubuntu

RUN <<EOF
su ubuntu
cd /home/ubuntu
mkdir runner
latest_runner_version=$(curl -I -v -s https://github.com/actions/runner/releases/latest 2>&1 | perl -ne 'next unless s/^< location: //; s{.*/v}{}; s/\s+//; print')
curl -sL "https://github.com/actions/runner/releases/download/v${latest_runner_version}/actions-runner-linux-x64-${latest_runner_version}.tar.gz" | tar xzvC ./runner/
sudo ./runner/bin/installdependencies.sh
python3 -m venv ./
source ./bin/activate
pip install -U platformio adafruit-nrfutil
pip install -U meshtastic --pre
EOF
