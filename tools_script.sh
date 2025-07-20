#!/bin/bash

# Ubuntu Bastion Host Setup Script
# This script automates the installation and configuration of development tools

set -e  # Exit on any error

echo "======================================"
echo "Ubuntu Bastion Host Setup Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_status "Starting Ubuntu bastion host setup..."

# 1. Configure vim
print_status "Configuring vim..."
cat > ~/.vimrc << 'EOF'
set nu
set paste
set cursorline
set cursorcolumn
EOF

# 2. Set EDITOR environment variable
print_status "Setting EDITOR environment variable..."
echo 'export EDITOR=/usr/bin/vim' >> ~/.bashrc

# 3. Set hostname (requires sudo)
print_status "Setting hostname to 'bastion'..."
sudo hostname bastion

# 4. Update package manager
print_status "Updating package manager..."
sudo apt update -y

# 5. Install basic tools and build dependencies
print_status "Installing basic tools and build dependencies..."
sudo apt install -y ca-certificates curl gnupg lsb-release git jq vim build-essential gcc net-tools

# 6. Set password for ubuntu user (interactive)
print_warning "You will be prompted to set a password for the ubuntu user:"
sudo passwd ubuntu

# 7. Install Homebrew
print_status "Installing Homebrew..."
if ! command_exists brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH
    echo >> /home/ubuntu/.bashrc
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/ubuntu/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
else
    print_status "Homebrew already installed"
    # Make sure brew is available in current session even if already installed
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true
fi

# 7.1. Install bash-completion via Homebrew
print_status "Installing bash-completion..."
brew install bash-completion
echo >> /home/ubuntu/.bashrc
echo '# Enable bash-completion' >> /home/ubuntu/.bashrc
echo '[[ -r "/home/linuxbrew/.linuxbrew/etc/profile.d/bash_completion.sh" ]] && . "/home/linuxbrew/.linuxbrew/etc/profile.d/bash_completion.sh"' >> /home/ubuntu/.bashrc

# 8. Install Docker
print_status "Installing Docker..."
if ! command_exists docker; then
    sudo apt install -y docker.io
    sudo gpasswd -a $USER docker
    
    print_warning "Docker installed. You may need to log out and back in for group changes to take effect."
else
    print_status "Docker already installed"
fi

# Install Docker CLI via Homebrew for better completion support
print_status "Installing Docker CLI via Homebrew..."
brew install docker

# Setup Docker completion
print_status "Setting up Docker bash completion..."
mkdir -p ~/.bash_completion.d
echo >> /home/ubuntu/.bashrc
echo '# Docker completion' >> /home/ubuntu/.bashrc
echo 'if [ -f ~/.bash_completion.d/docker ]; then' >> /home/ubuntu/.bashrc
echo '    source ~/.bash_completion.d/docker' >> /home/ubuntu/.bashrc
echo 'fi' >> /home/ubuntu/.bashrc

# Generate Docker completion
docker completion bash > ~/.bash_completion.d/docker 2>/dev/null || true

# 9. Install Trivy via Homebrew
print_status "Installing Trivy..."
if ! command_exists trivy; then
    # Install gcc via brew as backup if system gcc isn't sufficient
    print_status "Installing gcc via Homebrew for Trivy compilation..."
    brew install gcc || true
    
    print_status "Installing Trivy (this may take a while as it compiles from source)..."
    brew install aquasecurity/trivy/trivy
    print_status "Trivy installed: $(which trivy)"
else
    print_status "Trivy already installed: $(which trivy)"
fi

# 10. Install AWS CLI via Homebrew
print_status "Installing AWS CLI..."
if ! command_exists aws; then
    brew install awscli
    print_status "AWS CLI installed: $(which aws)"
else
    print_status "AWS CLI already installed: $(which aws)"
fi

# 11. Install kubectl via Homebrew
print_status "Installing kubectl..."
if ! command_exists kubectl; then
    brew install kubectl
    print_status "kubectl installed: $(which kubectl)"
else
    print_status "kubectl already installed: $(which kubectl)"
fi

# Setup kubectl completion
print_status "Setting up kubectl bash completion..."
mkdir -p ~/.bash_completion.d

# Generate kubectl completion (using the working approach)
if command_exists kubectl; then
    kubectl completion bash > ~/.bash_completion.d/kubectl 2>/dev/null && \
    print_status "kubectl completion file generated successfully" || \
    print_warning "Failed to generate kubectl completion file"
    
    # Add direct source to bashrc (this is the working method)
    echo 'source ~/.bash_completion.d/kubectl' >> ~/.bashrc
    print_status "kubectl completion added to ~/.bashrc"
    
    # Verify the completion file was created and has content
    if [ -s ~/.bash_completion.d/kubectl ]; then
        print_status "kubectl completion file verified"
    else
        print_warning "kubectl completion file is empty or missing"
    fi
else
    print_error "kubectl not found in PATH, cannot generate completion"
fi

# 12. Source bashrc to apply changes
print_status "Reloading bash configuration..."
source ~/.bashrc 2>/dev/null || true

echo ""
print_status "======================================"
print_status "Setup completed successfully!"
print_status "======================================"
echo ""

# Display installed versions
print_status "Installed tool versions:"
echo "Git: $(git --version 2>/dev/null || echo 'Not found')"
echo "Docker: $(docker --version 2>/dev/null || echo 'Not found - may need to re-login')"
echo "Brew: $(brew --version 2>/dev/null | head -1 || echo 'Not found')"
echo "Trivy: $(trivy --version 2>/dev/null || echo 'Not found')"
echo "AWS CLI: $(aws --version 2>/dev/null || echo 'Not found')"
echo "kubectl: $(kubectl version --client --short 2>/dev/null || echo 'Not found')"

echo ""
print_warning "Important notes:"
echo "1. You may need to log out and back in for Docker group changes to take effect"
echo "2. Run 'source ~/.bashrc' or open a new terminal to ensure all PATH changes are loaded"
echo "3. The hostname change will persist until reboot unless you also update /etc/hostname"
echo "4. If 'which aws/kubectl/trivy' returns nothing, run: eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\""
echo "5. If kubectl completion doesn't work, try: kubectl completion bash > ~/.bash_completion.d/kubectl && source ~/.bashrc"
echo ""

print_status "Script execution completed!"
