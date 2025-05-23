# Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Python
sudo apt-get install python3.6
sudo apt install python3-pip -y
sudo apt install python3.11-venv -y

# Dapr
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
dapr init

# Quickstart
git clone https://github.com/dapr/dapr-agents.git
cd dapr-agents/quickstarts