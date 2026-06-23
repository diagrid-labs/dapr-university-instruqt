# Base image is the Instruqt docker image. So docker in docker is available
# Host is Ubuntu 24.04
# Shell = bash

# Python
apt-get update
sudo apt-get install python3.6
sudo apt install python3-pip -y
sudo apt install python3.11-venv -y
