# Runs at every sandbox launch.
# Clone the Spring AI sample source (public repo) into the learner's working directory.
git clone https://github.com/diagridio/catalyst-quickstarts.git

# Download and install the Diagrid CLI.
curl -o- https://downloads.diagrid.io/cli/install.sh | bash
sudo mv ./diagrid /usr/local/bin

# Pre-download Maven dependencies so the first build in challenge 1 is instant.
cd catalyst-quickstarts/agents/spring-ai/event-planner && mvn package -DskipTests -q
