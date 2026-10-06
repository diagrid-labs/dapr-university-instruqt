# Build this challenge's demo so the learner's `dapr run -f .` starts without a
# package restore.
cd dapr-pub-sub-deep-dive || exit 0

dotnet build Demo7-Resiliency/SenderService
dotnet build Demo7-Resiliency/ReceiverService
dotnet build Demo7-Resiliency/DeadLetterService
