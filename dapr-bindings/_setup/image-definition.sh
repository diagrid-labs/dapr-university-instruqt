# The base image is the Instruqt docker image, this has docker installed
# Host is Ubuntu 24.04

# Update package index
sudo apt-get update

# Python
sudo apt-get install python3.12 -y
sudo apt install python3-pip -y
sudo apt install python3.12-venv -y

# Pre-pull the Postgres image so the container in sandbox-setup.sh starts instantly.
docker pull postgres:16
