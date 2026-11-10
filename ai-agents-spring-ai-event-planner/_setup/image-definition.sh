# The base image is the Instruqt docker image, this has docker installed
# Host is Ubuntu 24.04

# Update package index
sudo apt-get update

# JDK 21 and Maven
sudo apt-get install openjdk-21-jdk maven -y
