FROM ubuntu:24.04
LABEL org.opencontainers.image.authors="Jonathan Bennett, vidplace7"
ARG TARGETARCH
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

COPY --chown=ubuntu:ubuntu bin/* /usr/local/bin/

RUN install-actions-runner.sh

WORKDIR /home/ubuntu
USER ubuntu

RUN <<EOF
python3 -m venv ./
source ./bin/activate
pip install -U platformio adafruit-nrfutil
pip install -U meshtastic --pre
EOF
