git clone https://github.com/dapr/dapr-agents.git

wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
docker login -u ${DockerUSER} -p ${DockerPAT}
dapr init
dapr -v

if [ -n "$(docker ps -f "name=dapr_placement" -f "status=running" -q )" ] && [ -n "$(docker ps -f "name=dapr_scheduler" -f "status=running" -q )" ] && [ -n "$(docker ps -f "name=dapr_redis" -f "status=running" -q )"  ] && [ -n "$(docker ps -f "name=dapr_zipkin" -f "status=running" -q )" ];
then
    echo "The Dapr containers are running! 👍"
else
    dapr uninstall
    dapr init
fi

wget -qO- https://astral.sh/uv/install.sh | sh