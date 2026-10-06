# Runs at every sandbox launch.
# Clone the MAF source (public repo) into the learner's working directory.
git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git

# Authenticate to Docker Hub to avoid anonymous pull rate limits.
docker login -u ${DockerUSER} -p ${DockerPAT}

# Initialize Dapr in self-hosted mode (Redis, placement, scheduler, zipkin containers).
dapr init