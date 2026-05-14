mkdir dapr-workflow-aspire
docker login -u ${DockerUSER} -p ${DockerPAT}
dapr init
docker pull ghcr.io/diagridio/diagrid-dashboard:latest
