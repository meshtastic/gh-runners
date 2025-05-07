#!/usr/bin/env bash

# This script installs the actions-runner application on a Linux system.

if [ "${TARGETARCH}" = "amd64" ]; then
    GH_ARCH="x64"
    GH_SOURCE="actions/runner"
elif [ "${TARGETARCH}" = "arm64" ]; then
    GH_ARCH="arm64"
    GH_SOURCE="actions/runner"
elif [ "${TARGETARCH}" = "arm" ]; then
    GH_ARCH="arm"
    GH_SOURCE="actions/runner"
elif [ "${TARGETARCH}" = "riscv64" ]; then
    GH_ARCH="riscv64"
    GH_SOURCE="dkurt/github_actions_riscv"
    # get custom dotnet env
    cd $HOME
    wget https://github.com/dkurt/dotnet_riscv/releases/download/v8.0.101/dotnet-sdk-8.0.101-linux-riscv64.tar.gz
    sudo mkdir /usr/share/dotnet
    cd /usr/share/dotnet
    sudo tar -xf $HOME/dotnet-sdk-8.0.101-linux-riscv64.tar.gz
    rm -f $HOME/dotnet-sdk-8.0.101-linux-riscv64.tar.gz
else
    echo "Unsupported architecture: ${TARGETARCH}"
    exit 1
fi

cd /home/ubuntu
mkdir runner
latest_runner_version=$(curl -I -v -s https://github.com/${GH_SOURCE}/releases/latest 2>&1 | perl -ne 'next unless s/^< location: //; s{.*/v}{}; s/\s+//; print')
curl -sL "https://github.com/${GH_SOURCE}/releases/download/v${latest_runner_version}/actions-runner-linux-${GH_ARCH}-${latest_runner_version}.tar.gz" | tar xzvC ./runner/
./runner/bin/installdependencies.sh
chown -R ubuntu:ubuntu /home/ubuntu/runner
