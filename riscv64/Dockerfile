FROM ubuntu:24.04
LABEL org.opencontainers.image.authors="Jonathan Bennett, vidplace7"
SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_ROOT_USER_ACTION=ignore

RUN <<EOF
useradd ubuntu -m -s /bin/bash
usermod -a -G sudo ubuntu
apt update
apt upgrade -y
apt install -y curl pip git python3-venv python3-grpc-tools pkg-config libicu-dev sudo podman zip jq wget gh devscripts
sed -i /etc/sudoers -re 's/^%sudo.*/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g'
ln -s /usr/bin/podman /usr/bin/docker
EOF

RUN <<EOF
cd /home/ubuntu
mkdir runner
latest_runner_version=$(curl -I -v -s https://github.com/dkurt/github_actions_riscv/releases/latest 2>&1 | perl -ne 'next unless s/^< location: //; s{.*/v}{}; s/\s+//; print')
curl -sL "https://github.com/dkurt/github_actions_riscv/releases/download/v${latest_runner_version}/actions-runner-linux-riscv64-${latest_runner_version}.tar.gz" | tar xzvC ./runner/
./runner/bin/installdependencies.sh
chown -R ubuntu:ubuntu /home/ubuntu/runner
EOF

WORKDIR /home/ubuntu
USER ubuntu

RUN <<EOF
python3 -m venv ./
source ./bin/activate
pip install -U platformio adafruit-nrfutil
pip install -U meshtastic --pre
EOF
