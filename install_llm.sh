#!/bin/bash

# Comprehensive LLM Installation and Setup Script

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[LLM INSTALLER]${NC} $1"
}

# Error handling function
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log "Detected Linux"
        INSTALL_CMD="sudo apt-get"
        PYTHON_CMD="python3"
        PIP_CMD="pip3"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log "Detected macOS"
        INSTALL_CMD="brew"
        PYTHON_CMD="python3"
        PIP_CMD="pip3"
    else
        error "Unsupported operating system"
    fi
}

# Prerequisites installation
install_prerequisites() {
    log "Installing prerequisites..."
    
    # Update package lists
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update
        sudo apt-get install -y \
            curl \
            wget \
            git \
            python3 \
            python3-pip \
            python3-venv \
            build-essential
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew update
        brew install \
            curl \
            wget \
            git \
            python
    fi

    # Ensure pip is up to date
    $PIP_CMD install --upgrade pip
}

# Install Ollama
install_ollama() {
    log "Installing Ollama..."
    
    # Ollama installation script
    curl https://ollama.ai/install.sh | sh
    
    # Start Ollama service
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo systemctl start ollama
        sudo systemctl enable ollama
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew services start ollama
    fi
}

# Pull Mistral Model
pull_mistral_model() {
    log "Pulling Mistral 4B model..."
    ollama pull mistral:4b-instruct-v0.1
}

# Create Python Virtual Environment
create_python_env() {
    log "Setting up Python virtual environment..."
    
    # Create project directory
    mkdir -p ~/llm-assistant
    cd ~/llm-assistant
    
    # Create virtual environment
    $PYTHON_CMD -m venv venv
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Install required Python packages
    pip install ollama
}

# Create Ollama CLI Assistant Script
create_cli_assistant() {
    log "Creating Ollama CLI Assistant script..."
    
    cat > ~/llm-assistant/ollama_cli_assistant.py << 'EOL'
import ollama
import subprocess
import json
import re

class OllamaCLIAssistant:
    def __init__(self, model='mistral:4b-instruct-v0.1'):
        self.model = model
        self.system_prompt = """
        You are an AI assistant that translates natural language requests into precise CLI commands. 
        Follow these strict guidelines:
        1. Always output a valid, safe CLI command
        2. Use bash/shell syntax
        3. Never include sudo or destructive commands without explicit confirmation
        4. Return JSON with two keys:
           - 'command': The exact CLI command to execute
           - 'explanation': A brief explanation of what the command does
        5. If the request is unclear or potentially dangerous, return an error message
        
        Examples:
        Input: "List all files in the current directory"
        Output: {"command": "ls -la", "explanation": "List all files in current directory, including hidden files"}
        
        Input: "What's the disk usage of my home directory?"
        Output: {"command": "du -sh ~", "explanation": "Calculate total disk usage of home directory"}
        """

    def generate_command(self, user_request):
        try:
            response = ollama.chat(
                model=self.model,
                messages=[
                    {'role': 'system', 'content': self.system_prompt},
                    {'role': 'user', 'content': user_request}
                ]
            )
            
            json_match = re.search(r'\{.*\}', response['message']['content'], re.DOTALL)
            if not json_match:
                return {
                    'error': 'Could not parse command',
                    'full_response': response['message']['content']
                }
            
            try:
                command_data = json.loads(json_match.group(0))
                return command_data
            except json.JSONDecodeError:
                return {
                    'error': 'Invalid JSON format',
                    'full_response': response['message']['content']
                }
        
        except Exception as e:
            return {
                'error': f'Error generating command: {str(e)}',
                'full_response': str(e)
            }

    def execute_command(self, command):
        try:
            result = subprocess.run(
                command, 
                shell=True, 
                capture_output=True, 
                text=True
            )
            
            return {
                'stdout': result.stdout,
                'stderr': result.stderr,
                'return_code': result.returncode
            }
        except Exception as e:
            return {
                'error': f'Execution error: {str(e)}'
            }

def main():
    assistant = OllamaCLIAssistant()
    
    print("Ollama CLI Assistant")
    print("Enter your natural language request (or 'exit' to quit)")
    
    while True:
        try:
            user_input = input("\n> ")
            
            if user_input.lower() in ['exit', 'quit', 'q']:
                break
            
            command_data = assistant.generate_command(user_input)
            
            if 'error' in command_data:
                print(f"Error: {command_data.get('error')}")
                print(f"Full Response: {command_data.get('full_response', 'No additional details')}")
                continue
            
            print(f"Command: {command_data.get('command', 'N/A')}")
            print(f"Explanation: {command_data.get('explanation', 'No explanation')}")
            
            confirm = input("Execute this command? (y/n): ").lower()
            if confirm == 'y':
                result = assistant.execute_command(command_data['command'])
                
                if 'error' in result:
                    print(f"Execution Error: {result['error']}")
                else:
                    if result['stdout']:
                        print("Output:\n", result['stdout'])
                    if result['stderr']:
                        print("Errors:\n", result['stderr'])
        
        except KeyboardInterrupt:
            print("\nOperation cancelled.")
            break
        except Exception as e:
            print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    main()
EOL

    # Make the script executable
    chmod +x ~/llm-assistant/ollama_cli_assistant.py
}

# Create launch script
create_launch_script() {
    log "Creating launch script..."
    
    cat > ~/llm-assistant/launch_assistant.sh << 'EOL'
#!/bin/bash

# Navigate to the LLM assistant directory
cd ~/llm-assistant

# Activate virtual environment
source venv/bin/activate

# Start Ollama CLI Assistant
python ollama_cli_assistant.py

# Deactivate virtual environment when done
deactivate
EOL

    chmod +x ~/llm-assistant/launch_assistant.sh
}

# Main installation function
main() {
    log "Starting LLM Installation Process..."
    
    # Detect OS
    detect_os
    
    # Install prerequisites
    install_prerequisites
    
    # Install Ollama
    install_ollama
    
    # Pull Mistral model
    pull_mistral_model
    
    # Setup Python environment
    create_python_env
    
    # Create CLI assistant
    create_cli_assistant
    
    # Create launch script
    create_launch_script
    
    log "Installation Complete!"
    log "Launch the assistant using: ~/llm-assistant/launch_assistant.sh"
}

# Run the main installation function
main
