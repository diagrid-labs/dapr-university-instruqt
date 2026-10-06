# Build this challenge's demo so the learner's `dapr run -f .` starts without a
# package restore.
cd dapr-pub-sub-deep-dive || exit 0

dotnet build Demo4-Bulk/SenderService
dotnet build Demo4-Bulk/ReceiverService1
dotnet build Demo4-Bulk/ReceiverService2
