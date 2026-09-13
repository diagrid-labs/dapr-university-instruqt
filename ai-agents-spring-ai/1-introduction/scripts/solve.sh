# NOTE: account creation and the device-code login are interactive by nature
# (they need a human to confirm a code in a browser), so they can't be fully
# automated from a script. This assumes an account already exists and the CLI
# is already logged in, and only handles the scriptable part.
echo 'export OPENAI_API_KEY="sk-solve-placeholder-key"' >> ~/.bashrc
source ~/.bashrc
