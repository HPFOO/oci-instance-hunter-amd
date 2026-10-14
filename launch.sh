#!/usr/bin/env bash
# ==============================================================================
# OCI Free Tier AMD Instance Hunter
# Repository: oci-instance-hunter-amd
# ==============================================================================

set -e

echo "=================================================="
echo "   OCI Free Tier AMD Instance Auto-Provisioner    "
echo "=================================================="

# 1. Resolve instance display name
MY_NAME="${VM_NAME:-$1}"
if [ -z "$MY_NAME" ]; then
  read -r -p "Enter instance name [Default: oci-amd-vm]: " input_name
  MY_NAME="${input_name:-oci-amd-vm}"
fi

# 2. Resolve SSH public key
PUB_KEY="${SSH_KEY:-$2}"

if [ -z "$PUB_KEY" ]; then
  if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    echo ">> Detected existing key: ~/.ssh/id_rsa.pub"
    PUB_KEY=$(cat "$HOME/.ssh/id_rsa.pub")
  elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    echo ">> Detected existing key: ~/.ssh/id_ed25519.pub"
    PUB_KEY=$(cat "$HOME/.ssh/id_ed25519.pub")
  else
    echo ">> No default SSH key detected."
    echo "   1) Specify a custom key file path (e.g., ~/.ssh/my_key.pub)"
    echo "   2) Paste public key string directly"
    echo "   3) Auto-generate a new ED25519 key pair on the fly"
    read -r -p "Select option [1/2/3, Default: 3]: " key_choice
    key_choice="${key_choice:-3}"

    if [ "$key_choice" == "1" ]; then
      while true; do
        read -r -p "Enter full path to your .pub file: " user_key_path
        eval expanded_path="$user_key_path"
        if [ -f "$expanded_path" ]; then
          PUB_KEY=$(cat "$expanded_path")
          echo ">> Successfully loaded key from: $expanded_path"
          break
        else
          echo "File not found at: $expanded_path. Please try again."
        fi
      done
    elif [ "$key_choice" == "2" ]; then
      read -r -p "Paste your full SSH Public Key string: " PUB_KEY
    else
      echo ">> Generating a new ED25519 key pair at ~/.ssh/id_ed25519..."
      mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
      ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" -C "oci-amd-auto-key"
      PUB_KEY=$(cat "$HOME/.ssh/id_ed25519.pub")
      echo ">> Key created successfully!"
    fi
  fi
fi

if [ -z "$PUB_KEY" ]; then
  echo "Error: No valid SSH public key provided."
  exit 1
fi

echo ">> Target Instance Name : $MY_NAME"
echo ">> Target VNIC Name     : ${MY_NAME}-vnic"

# 3. Retrieve OCI tenancy and availability domain
echo ">> Querying OCI tenancy & availability domain..."
COMP_ID=$(oci iam tenancy get --tenancy-id "$OCI_TENANCY" --query "data.id" --raw-output)
AD_NAME=$(oci iam availability-domain list --compartment-id "$COMP_ID" --query "data[0].name" --raw-output)

# 4. Check or create dedicated isolated VCN
VCN_NAME="${MY_NAME}-vcn"
echo ">> Verifying isolated network: ${VCN_NAME}..."
VCN_ID=$(oci network vcn list --compartment-id "$COMP_ID" --display-name "$VCN_NAME" --query "data[0].id" --raw-output 2>/dev/null || true)

if [ -z "$VCN_ID" ] || [ "$VCN_ID" == "None" ] || [ "$VCN_ID" == "null" ]; then
  echo ">> Creating dedicated VCN (192.168.0.0/16)..."
  VCN_ID=$(oci network vcn create --compartment-id "$COMP_ID" --cidr-block "192.168.0.0/16" --display-name "$VCN_NAME" --query "data.id" --raw-output)

  echo ">> Creating Internet Gateway..."
  IG_ID=$(oci network internet-gateway create --compartment-id "$COMP_ID" --vcn-id "$VCN_ID" --is-enabled true --display-name "${MY_NAME}-igw" --query "data.id" --raw-output)

  echo ">> Configuring default route (0.0.0.0/0 -> IGW)..."
  RT_ID=$(oci network route-table list --compartment-id "$COMP_ID" --vcn-id "$VCN_ID" --query "data[0].id" --raw-output)
  oci network route-table update --rt-id "$RT_ID" --route-rules "[{\"cidrBlock\":\"0.0.0.0/0\",\"networkEntityId\":\"$IG_ID\"}]" --force > /dev/null

  echo ">> Creating Public Subnet (192.168.1.0/24)..."
  SUB_ID=$(oci network subnet create --compartment-id "$COMP_ID" --vcn-id "$VCN_ID" --cidr-block "192.168.1.0/24" --display-name "${MY_NAME}-subnet" --query "data.id" --raw-output)
else
  echo ">> Reusing existing isolated network ($VCN_ID)..."
  SUB_ID=$(oci network subnet list --compartment-id "$COMP_ID" --vcn-id "$VCN_ID" --display-name "${MY_NAME}-subnet" --query "data[0].id" --raw-output)
fi

# 5. Resolve Ubuntu 22.04 LTS x86_64 image
echo ">> Resolving latest Ubuntu 22.04 LTS x86_64 image..."
IMG_ID=$(oci compute image list --compartment-id "$COMP_ID" \
  --operating-system "Canonical Ubuntu" \
  --shape "VM.Standard.E2.1.Micro" \
  --sort-by TIMECREATED --sort-order DESC \
  --query "data[?contains(\"display-name\", '22.04')].id | [0]" --raw-output)

# 6. Write metadata payload safely
cat << EOF > metadata.json
{"ssh_authorized_keys": "$PUB_KEY"}
EOF

# 7. Fault-Domain polling loop
COUNT=0
FDS=("FAULT-DOMAIN-1" "FAULT-DOMAIN-2" "FAULT-DOMAIN-3")

echo "--------------------------------------------------"
echo "Hunting for capacity. Press Ctrl+C to terminate."
echo "--------------------------------------------------"

while true; do
  FD=${FDS[$((COUNT % 3))]}
  echo "[Attempt $COUNT] Probing capacity in $FD..."

  OUTPUT=$(oci compute instance launch \
    --compartment-id "$COMP_ID" \
    --availability-domain "$AD_NAME" \
    --fault-domain "$FD" \
    --shape "VM.Standard.E2.1.Micro" \
    --boot-volume-size-in-gbs 50 \
    --subnet-id "$SUB_ID" \
    --assign-public-ip true \
    --vnic-display-name "${MY_NAME}-vnic" \
    --image-id "$IMG_ID" \
    --display-name "$MY_NAME" \
    --metadata file://metadata.json \
    2>&1) || true

  if echo "$OUTPUT" | grep -qi 'PROVISIONING'; then
    echo "=================================================="
    echo "SUCCESS: AMD Instance provisioned successfully!"
    echo "=================================================="
    rm -f metadata.json
    break
  fi

  if echo "$OUTPUT" | grep -q "TooManyRequests"; then
    SLEEP=$((RANDOM % 54 + 108))
    echo ">> Rate limit hit. Backing off for ${SLEEP}s..."
    sleep "$SLEEP"
  elif echo "$OUTPUT" | grep -iq "Out of host capacity"; then
    SLEEP=$((RANDOM % 41 + 40))
    echo ">> Out of capacity in $FD. Retrying next FD in ${SLEEP}s..."
    sleep "$SLEEP"
  else
    echo ">> Non-capacity error encountered:"
    echo "$OUTPUT"
    rm -f metadata.json
    exit 1
  fi

  COUNT=$((COUNT + 1))
done
