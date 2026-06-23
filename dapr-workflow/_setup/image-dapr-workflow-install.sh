# Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Python
sudo apt-get install python3.12
sudo apt-get update
sudo apt install python3-pip -y
sudo apt install python3.12-venv -y

# .NET
wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install dotnet-sdk-10.0 -y

# Java
sudo apt install openjdk-17-jdk maven -y

# Node (the NodeSource nodejs package already bundles npm)
curl -fsSL https://deb.nodesource.com/setup_24.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt-get install -y nodejs

# Go
sudo apt install golang -y