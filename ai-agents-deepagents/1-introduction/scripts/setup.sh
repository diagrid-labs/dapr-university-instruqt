git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git

cd ai-agent-tracks-instruqt/deepagents/deep-investigation

# Provision the OpenAI API key from the OPENAI_API_KEY Instruqt sandbox secret into the
# .env read by load_dotenv() in the investigate-*.py scripts, so the learner doesn't
# have to supply their own key.
cat > .env <<EOF
OPENAI_API_KEY=${OPENAI_API_KEY}
EOF

# Install the Dapr Dev Dashboard into a directory that's on every shell's PATH
curl -sSL https://raw.githubusercontent.com/diagridio/dev-dashboard/main/scripts/install.sh | BIN_DIR=/usr/local/bin sh
