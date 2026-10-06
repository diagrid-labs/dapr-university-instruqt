# Build this challenge's demo so the learner's `dapr run -f .` starts without a
# package restore. The Dapr SDK packages are already in the NuGet cache after
# _setup/sandbox-setup.sh, so this is quick.
cd dapr-pub-sub-deep-dive || exit 0

dotnet build Demo5-CloudEvents/SenderService
dotnet build Demo5-CloudEvents/ReceiverService
