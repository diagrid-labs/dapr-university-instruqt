# Build the demos used in this challenge so the learner's first `dapr run -f .`
# starts without a package restore. Demo1 is already built by
# _setup/sandbox-setup.sh; Demo2 and Demo3 are built here.
cd dapr-pub-sub-deep-dive || exit 0

dotnet build Demo2-Programmatic/SenderService
dotnet build Demo2-Programmatic/ReceiverService
dotnet build Demo3-Streaming/SenderService
dotnet build Demo3-Streaming/ReceiverService
