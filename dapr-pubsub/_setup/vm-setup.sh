# Base image is the Instruqt docker image.
# Host is Ubuntu 24.04
# Shell = bash
#
# This script builds the base VM image once. Keep it in sync with the tools the
# assignments assume are preinstalled: Docker, the .NET 10 SDK, the Dapr CLI,
# jq, and git. The Dapr Pub/Sub Deep Dive projects all target net10.0, so the
# .NET 10 SDK is a hard requirement.

# Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# .NET 10 SDK
sudo add-apt-repository -y ppa:dotnet/backports
sudo apt-get update && \
  sudo apt-get install -y dotnet-sdk-10.0

# jq (used to pretty-print CloudEvent envelopes in challenge 2)
sudo apt-get install -y jq

# Dapr CLI
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash

source /root/.bashrc
