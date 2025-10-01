#!/bin/bash
echo "=== SIS2 Setup Script for Simple Fit Infrastructure ==="
echo "Starting automated setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Step 1: Creating groups..."
sudo groupadd app_managers || print_warning "Group app_managers may already exist"
sudo groupadd db_managers || print_warning "Group db_managers may already exist"
sudo groupadd monitoring || print_warning "Group monitoring may already exist"

print_status "Step 2: Creating users and adding to groups..."

if id "postgres" &>/dev/null; then
    print_warning "User postgres already exists"
else
    sudo adduser --system --home /var/lib/postgresql --shell /bin/bash --group postgres
fi
sudo usermod -aG db_managers postgres

if id "minio" &>/dev/null; then
    print_warning "User minio already exists"
else
    sudo adduser --system --home /var/lib/minio --shell /bin/bash minio
fi
sudo usermod -aG app_managers minio

if id "app_backend" &>/dev/null; then
    print_warning "User app_backend already exists"
else
    sudo adduser --system --home /srv/app --shell /bin/bash app_backend
fi
sudo usermod -aG app_managers app_backend

if id "app_frontend" &>/dev/null; then
    print_warning "User app_frontend already exists"
else
    sudo adduser --system --home /var/www/html --shell /bin/bash app_frontend
fi
sudo usermod -aG app_managers app_frontend

if id "monitoring" &>/dev/null; then
    print_warning "User monitoring already exists"
else
    sudo adduser --system --home /var/lib/prometheus --shell /bin/bash monitoring
fi
sudo usermod -aG monitoring monitoring

if id "automation_bot" &>/dev/null; then
    print_warning "User automation_bot already exists"
else
    sudo adduser --system --home /home/automation_bot --shell /bin/bash automation_bot
fi
sudo usermod -aG app_managers automation_bot

if id "sys_admin" &>/dev/null; then
    print_warning "User sys_admin already exists"
else
    sudo adduser sys_admin
fi
sudo usermod -aG sudo sys_admin

print_status "User creation completed"

print_status "Step 3: Creating directories and setting file permissions..."

sudo mkdir -p /srv/app/uploads /srv/app/tmp
sudo mkdir -p /var/www/html

sudo chown -R app_backend:app_managers /srv/app/
sudo chmod -R 775 /srv/app/

sudo chown -R app_frontend:app_managers /var/www/html/
sudo chmod -R 755 /var/www/html/

sudo mkdir -p /var/lib/minio
sudo chown minio:minio /var/lib/minio

sudo mkdir -p /var/lib/prometheus
sudo chown monitoring:monitoring /var/lib/prometheus

print_status "Directory setup completed"

print_status "Step 4: Configuring sudo permissions..."

echo "app_frontend ALL=(root) NOPASSWD: /usr/bin/systemctl reload nginx, /usr/bin/systemctl restart nginx" | sudo tee /etc/sudoers.d/app_frontend

echo "automation_bot ALL=(root) NOPASSWD: /usr/bin/docker, /usr/bin/systemctl restart app_backend, /usr/bin/apt update, /usr/bin/apt upgrade" | sudo tee /etc/sudoers.d/automation_bot

sudo chmod 440 /etc/sudoers.d/app_frontend
sudo chmod 440 /etc/sudoers.d/automation_bot

print_status "Validating sudoers configuration..."
if sudo visudo -c; then
    print_status "Sudoers configuration is valid"
else
    print_error "Sudoers configuration contains errors!"
    exit 1
fi

print_status "Step 5: Setting up SSH for automation_bot..."

sudo -u automation_bot bash << 'EOF'
set -e

echo "Setting up SSH as automation_bot user..."

# Create SSH directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Generate SSH key pair if it doesn't exist
if [ ! -f ~/.ssh/automation_bot_key ]; then
    echo "Generating new SSH key pair..."
    ssh-keygen -t ed25519 -C "gitlab_runner_key" -f ~/.ssh/automation_bot_key -N ""
else
    echo "SSH key pair already exists"
fi

# Display public key for manual copying
echo ""
echo "=== IMPORTANT: SSH PUBLIC KEY ==="
cat ~/.ssh/automation_bot_key.pub
echo "=== END OF PUBLIC KEY ==="
echo ""
echo "Please copy the above public key for CI/CD configuration"
echo "For manual connection test, use:"
echo "ssh -i ~/.ssh/automation_bot_key automation_bot@$(hostname -I | awk '{print $1}')"

EOF

print_status "Step 6: Performing final checks..."

echo ""
print_status "User and Group Verification:"
echo "Users in app_managers group:"
getent group app_managers
echo ""
echo "Users in db_managers group:"
getent group db_managers
echo ""
echo "Users in monitoring group:"
getent group monitoring

echo ""
print_status "Sudo Permissions Summary:"
echo "app_frontend permissions:"
sudo -l -U app_frontend
echo ""
echo "automation_bot permissions:"
sudo -l -U automation_bot

echo ""
print_status "Directory Permissions:"
echo "/srv/app permissions:"
ls -la /srv/app/
echo ""
echo "/var/www/html permissions:"
ls -la /var/www/html/