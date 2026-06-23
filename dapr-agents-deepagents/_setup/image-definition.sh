# The base image is the Instruqt Docker image, this has docker installed

# Update package index
sudo apt-get update

# Python
sudo apt-get install python3.12
sudo apt install python3-pip -y
sudo apt install python3.12-venv -y

# .NET 10 SDK (from Ubuntu's own feed on 24.04 — do NOT add the Microsoft repo,
# mixing it with Ubuntu's .NET packages causes a /usr/bin/dnx file conflict)
sudo apt-get install dotnet-sdk-10.0 -y

# Node
curl -fsSL https://deb.nodesource.com/setup_24.x -o nodesource_setup.sh
bash nodesource_setup.sh node
sudo apt-get install nodejs -y

# Ollama (CPU-only on a standard VM — keep to small models)
curl -fsSL https://ollama.com/install.sh | sh

# Pre-pull small models at build time so they're cached in the image.
# Start the server in the background just for the pulls.
ollama serve &
ollama pull llama3.2:3b
ollama pull qwen3.5:2b

# GitHub CLI
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install gh -y

