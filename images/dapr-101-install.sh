# Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Python
sudo apt-get install python3.6
sudo apt install python3-pip -y
sudo apt install python3.11-venv -y

# .NET
wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install dotnet-sdk-8.0 -y

# Java
sudo apt install openjdk-17-jdk maven -y

# Node
curl -fsSL https://deb.nodesource.com/setup_22.x -o nodesource_setup.sh
bash nodesource_setup.shnode
sudo apt-get install nodejs npm -y
