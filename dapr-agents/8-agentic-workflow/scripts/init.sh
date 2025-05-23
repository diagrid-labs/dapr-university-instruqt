cd 04-agentic-workflow/

# Create a virtual environment
python3.10 -m venv .venv

# Activate the virtual environment
# On Windows:
.venv\Scripts\activate
# On macOS/Linux:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt


cat > .env << EOF
OPENAI_API_KEY=your_openai_api_key_here
EOF
