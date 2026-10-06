# Runs at every sandbox launch.

# Clone the demo source (public repo) into the learner's working directory.
git clone https://github.com/diagrid-labs/dapr-pub-sub-deep-dive.git

# Authenticate to Docker Hub to avoid anonymous pull rate limits.
docker login -u ${DockerUSER} -p ${DockerPAT}

# Initialize Dapr in self-hosted mode (Redis, placement, scheduler, zipkin containers).
# The Redis container it starts is the message broker every demo publishes to.
dapr init

# Versions rendered by the Instruqt-Var placeholders in 1-subscriptions/assignment.md.
agent variable set DAPR_CLI_VERSION 1.18.0
agent variable set DAPR_RUNTIME_VERSION 1.18.0

# Warm the NuGet cache and build the first demo, so the learner's first
# `dapr run -f .` starts in seconds instead of restoring packages. Every later
# challenge builds its own demo in scripts/setup.sh, which is fast once the
# Dapr SDK packages are cached here.
dotnet build dapr-pub-sub-deep-dive/Demo1-Declarative/SenderService
dotnet build dapr-pub-sub-deep-dive/Demo1-Declarative/ReceiverService
