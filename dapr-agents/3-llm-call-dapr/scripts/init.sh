cd 02_llm_call_dapr/

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
DAPR_LLM_COMPONENT_DEFAULT=openai
EOF
