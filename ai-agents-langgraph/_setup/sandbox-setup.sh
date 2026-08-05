# Runs at every sandbox launch.
# Clone the LangGraph sample source (public repo) into the learner's working directory.
git clone https://github.com/diagridio/catalyst-quickstarts.git

# Authenticate to Docker Hub to avoid anonymous pull rate limits.
docker login -u ${DockerUSER} -p ${DockerPAT}

wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
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

# Install project dependencies so the first `uv run` in challenge 1 is instant.
cd catalyst-quickstarts/agents/langgraph && ~/.local/bin/uv sync
