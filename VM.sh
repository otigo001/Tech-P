#!/bin/bash

echo "azure resource creation script"

# ============================================================
# Tech-P Azure Infrastructure
# Creates:
#   - Resource Group
#   - VNet
#   - Web/App/DB subnets
#   - NSGs
#   - Public IP
#   - Private IP
#   - Storage Account
#   - NIC
#   - Ubuntu Linux VM
# ============================================================

# -----------------------------
# Configuration
# -----------------------------

# Ask the user for the project name
read -p "Enter the project name: " Tech-P

PROJECT="Tech-P"
ENVIRONMENT="Prod"
LOCATION="ukwest"

RESOURCE_GROUP="${PROJECT}-${ENVIRONMENT}-RG"

VNET_NAME="${PROJECT}-${ENVIRONMENT}-VNet"
VNET_ADDRESS="10.10.0.0/16"

WEB_SUBNET_NAME="${PROJECT}-${ENVIRONMENT}-Web-Subnet"
WEB_SUBNET_PREFIX="10.10.1.0/24"

APP_SUBNET_NAME="${PROJECT}-${ENVIRONMENT}-App-Subnet"
APP_SUBNET_PREFIX="10.10.2.0/24"

DB_SUBNET_NAME="${PROJECT}-${ENVIRONMENT}-DB-Subnet"
DB_SUBNET_PREFIX="10.10.3.0/24"

VM_NAME="${PROJECT}-${ENVIRONMENT}-VM"
VM_SIZE="Standard_B2s"

NIC_NAME="${PROJECT}-${ENVIRONMENT}-NIC"

PUBLIC_IP_NAME="${PROJECT}-${ENVIRONMENT}-PublicIP"

WEB_NSG_NAME="${PROJECT}-${ENVIRONMENT}-Web-NSG"
APP_NSG_NAME="${PROJECT}-${ENVIRONMENT}-App-NSG"
DB_NSG_NAME="${PROJECT}-${ENVIRONMENT}-DB-NSG"

STORAGE_ACCOUNT_NAME="${PROJECT}${ENVIRONMENT}storage" 
STORAGE_CONTAINER_NAME="techp-data"

SSH_KEY_NAME="tech-p-azure"

# Static private IP for the VM
VM_PRIVATE_IP="10.10.2.10"

# ============================================================
# Login check
# ============================================================

echo "Checking Azure CLI login..."

if ! az account show >/dev/null 2>&1; then
    echo "Not logged in to Azure."
    echo "Running az login..."
    az login
fi

echo "Azure login OK."

# ============================================================
# Create Resource Group
# ============================================================

echo "Creating Resource Group..."

az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION"

# ============================================================
# Create VNet
# ============================================================

echo "Creating VNet..."

az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --location "$LOCATION" \
    --address-prefixes "$VNET_ADDRESS"

# ============================================================
# Create Subnets
# ============================================================

echo "Creating Web subnet..."

az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$WEB_SUBNET_NAME" \
    --address-prefixes "$WEB_SUBNET_PREFIX"

echo "Creating App subnet..."

az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$APP_SUBNET_NAME" \
    --address-prefixes "$APP_SUBNET_PREFIX"

echo "Creating DB subnet..."

az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$DB_SUBNET_NAME" \
    --address-prefixes "$DB_SUBNET_PREFIX"

# ============================================================
# Create NSGs
# ============================================================

echo "Creating Web NSG..."

az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$WEB_NSG_NAME" \
    --location "$LOCATION"

echo "Creating App NSG..."

az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NSG_NAME" \
    --location "$LOCATION"

echo "Creating DB NSG..."

az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DB_NSG_NAME" \
    --location "$LOCATION"

# ============================================================
# WEB NSG RULES
# ============================================================

# HTTP
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$WEB_NSG_NAME" \
    --name Allow-HTTP \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes Internet \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 80

# HTTPS
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$WEB_NSG_NAME" \
    --name Allow-HTTPS \
    --priority 110 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes Internet \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 443

# SSH
# For production, replace YOUR_PUBLIC_IP/32 with your actual public IP.
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$WEB_NSG_NAME" \
    --name Allow-SSH \
    --priority 120 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes Internet \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 22

# ============================================================
# APP NSG RULES
# ============================================================

# Allow application traffic from Web subnet
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$APP_NSG_NAME" \
    --name Allow-Web-To-App \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes "$WEB_SUBNET_PREFIX" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 8080

# SSH from Web subnet
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$APP_NSG_NAME" \
    --name Allow-SSH-From-Web \
    --priority 110 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes "$WEB_SUBNET_PREFIX" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 22

# ============================================================
# DB NSG RULES
# ============================================================

# PostgreSQL
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$DB_NSG_NAME" \
    --name Allow-PostgreSQL-From-App \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes "$APP_SUBNET_PREFIX" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 5432

# MySQL
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$DB_NSG_NAME" \
    --name Allow-MySQL-From-App \
    --priority 110 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes "$APP_SUBNET_PREFIX" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 3306

# ============================================================
# Associate NSGs with Subnets
# ============================================================

echo "Associating Web NSG..."

az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$WEB_SUBNET_NAME" \
    --network-security-group "$WEB_NSG_NAME"

echo "Associating App NSG..."

az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$APP_SUBNET_NAME" \
    --network-security-group "$APP_NSG_NAME"

echo "Associating DB NSG..."

az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$DB_SUBNET_NAME" \
    --network-security-group "$DB_NSG_NAME"

# ============================================================
# Create Public IP
# ============================================================

echo "Creating Public IP..."

az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --location "$LOCATION" \
    --allocation-method Static \
    --sku Standard

# ============================================================
# Create Network Interface
# ============================================================

echo "Creating NIC..."

az network nic create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC_NAME" \
    --location "$LOCATION" \
    --vnet-name "$VNET_NAME" \
    --subnet "$APP_SUBNET_NAME" \
    --private-ip-address "$VM_PRIVATE_IP" \
    --public-ip-address "$PUBLIC_IP_NAME"

# ============================================================
# Generate SSH key
# ============================================================

if [ ! -f "$HOME/.ssh/${SSH_KEY_NAME}" ]; then
    echo "Generating SSH key..."

    ssh-keygen \
        -t ed25519 \
        -f "$HOME/.ssh/${SSH_KEY_NAME}" \
        -N ""
fi

# ============================================================
# Create VM
# ============================================================

echo "Creating Ubuntu VM..."

az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --location "$LOCATION" \
    --nics "$NIC_NAME" \
    --image Ubuntu2404 \
    --size "$VM_SIZE" \
    --admin-username azureadmin \
    --ssh-key-values "$HOME/.ssh/${SSH_KEY_NAME}.pub" \
    --os-disk-size-gb 30 \
    --storage-sku StandardSSD_LRS
az vm identity assign \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --role "contributors" \

    vm_principal_id=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --query identity.principalId \
    --output tsv)
# ============================================================
# Create Storage Account
# ============================================================  

echo
echo "Creating Storage Account..."
az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS

    storage_account_id=$(az storage account show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --query id \
    --output tsv)   
az role assignment create \
    --assignee "$vm_principal_id" \
    --role "Storage Blob Data Contributor" \
    --scope "$storage_account_id"
    

echo "=========================================="
echo "        Tech-P Azure Environment"
echo "=========================================="
echo ""

PUBLIC_IP=$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --query ipAddress \
    --output tsv)

PRIVATE_IP=$(az network nic show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC_NAME" \
    --query "ipConfigurations[0].privateIPAddress" \
    --output tsv)

echo "Resource Group : $RESOURCE_GROUP"
echo "VNet           : $VNET_NAME"
echo "VNet CIDR      : $VNET_ADDRESS"
echo ""
echo "Web Subnet     : $WEB_SUBNET_PREFIX"
echo "App Subnet     : $APP_SUBNET_PREFIX"
echo "DB Subnet      : $DB_SUBNET_PREFIX"
echo ""
echo "VM             : $VM_NAME"
echo "Private IP     : $PRIVATE_IP"
echo "Public IP      : $PUBLIC_IP"
echo "vm identity assigned : $vm_principal_id"
echo ""
echo "Storage Account : $STORAGE_ACCOUNT_NAME"
echo "role assignment : Storage Blob Data Contributor"
echo "SSH:"
echo "ssh -i ~/.ssh/${SSH_KEY_NAME} azureadmin@${PUBLIC_IP}"
echo ""
echo "=========================================="
echo "Deployment complete."
echo "=========================================="

done 