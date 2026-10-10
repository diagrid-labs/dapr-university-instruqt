# Runs at every sandbox launch.
# Clone the Venue Bookings sample source (public repo) into the learner's working directory.
git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git

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

# Start the local Postgres container the bindings component connects to. init.sql
# (mounted read-only into Postgres's own init directory) creates the `bookings`
# table the first time the container boots. It is identical in every language folder.
docker run -d --name dapr_postgres \
  -e POSTGRES_PASSWORD=dapr123 \
  -e POSTGRES_DB=venuedb \
  -p 5432:5432 \
  -v "$(pwd)/ai-agent-tracks-instruqt/bindings/venue-bookings/python/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  postgres:16

wget -qO- https://astral.sh/uv/install.sh | sh

# Install the dependencies for all three languages so the first run in
# challenge 2 is quick, whichever language the learner picks.
cd ai-agent-tracks-instruqt/bindings/venue-bookings
(cd python && ~/.local/bin/uv sync)
(cd dotnet && dotnet restore)
(cd java && mvn -q -B package -DskipTests)
