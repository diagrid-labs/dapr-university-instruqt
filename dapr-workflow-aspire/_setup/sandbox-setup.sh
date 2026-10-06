mkdir dapr-workflow-aspire
docker login -u ${DockerUSER} -p ${DockerPAT}

wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
dapr init

