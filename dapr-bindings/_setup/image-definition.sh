# The base image is the Instruqt docker image, this has docker installed
# Host is Ubuntu 24.04

# Update package index
sudo apt-get update

# Python
sudo apt-get install python3.12 -y
sudo apt install python3-pip -y
sudo apt install python3.12-venv -y

# .NET 8 SDK (from Ubuntu's own feed on 24.04, do NOT add the Microsoft repo,
# mixing it with Ubuntu's .NET packages causes a /usr/bin/dnx file conflict)
sudo apt-get install dotnet-sdk-8.0 -y

# Java and Maven
sudo apt-get install openjdk-17-jdk maven -y

# Pre-pull the Postgres image so the container in sandbox-setup.sh starts instantly.
docker pull postgres:16
