# Build this challenge's demo so the learner's `dapr run -f .` starts without a
# package restore.
cd dapr-pub-sub-deep-dive || exit 0

dotnet build Demo6-Routing/SenderService
dotnet build Demo6-Routing/ReceiverService1
dotnet build Demo6-Routing/ReceiverService2
