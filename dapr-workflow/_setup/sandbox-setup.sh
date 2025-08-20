wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
docker login -u ${DockerUSER} -p ${DockerPAT}
dapr init

git clone https://github.com/dapr/quickstarts.git