# Runs at every sandbox launch.
# Clone the MAF source (public repo) into the learner's working directory.
git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git

# Authenticate to Docker Hub to avoid anonymous pull rate limits.
docker login -u ${DockerUSER} -p ${DockerPAT}

# Initialize Dapr in self-hosted mode (Redis, placement, scheduler, zipkin containers).
dapr init

# Pre-pull the Diagrid Dev Dashboard image so it starts quickly if used.
docker pull ghcr.io/diagridio/diagrid-dashboard:latest
