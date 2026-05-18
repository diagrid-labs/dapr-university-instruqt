# Base image is the Instruqt docker image. 
# Host is Ubuntu 24.04
# Shell = bash

# Install .NET 10
sudo add-apt-repository ppa:dotnet/backports

sudo apt-get update && \
  sudo apt-get install -y dotnet-sdk-10.0

# Install Dapr CLI

wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash

# Install Aspire CLI
curl -sSL https://aspire.dev/install.sh | /bin/bash

source /root/.bashrc