git clone https://github.com/dapr/quickstarts.git
docker login -u ${DockerUSER} -p ${DockerPAT}

agent variable set DAPR_CLI_VERSION 1.19.0
agent variable set DAPR_RUNTIME_VERSION 1.19.0

wget -qO- https://astral.sh/uv/install.sh | sh