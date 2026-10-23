# The base image is the Instruqt docker image, this has docker installed
# Host is Ubuntu 24.04

# Update package index
sudo apt-get update

# Python
sudo apt-get install python3.12 -y
sudo apt install python3-pip -y
sudo apt install python3.12-venv -y

# .NET 10 SDK (from Ubuntu's own feed on 24.04, do NOT add the Microsoft repo,
# mixing it with Ubuntu's .NET packages causes a /usr/bin/dnx file conflict)
sudo apt-get install software-properties-common -y
sudo add-apt-repository -y ppa:dotnet/backports
sudo apt-get update
sudo apt-get install dotnet-sdk-10.0 -y

# Java 21; each Java sample includes a Maven Wrapper.
sudo apt-get install openjdk-21-jdk curl unzip -y

# Pre-pull the Postgres image so the container in sandbox-setup.sh starts instantly.
docker pull postgres:16
