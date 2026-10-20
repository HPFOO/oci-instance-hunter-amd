# 👨🏻‍💻 OCI Free Tier AMD Instance Hunter

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Oracle%20Cloud-red.svg)](https://cloud.oracle.com/)
[![Shape](https://img.shields.io/badge/Shape-VM.Standard.E2.1.Micro-blue.svg)]()

An automated, zero-dependency Bash script to hunt and launch an **Oracle Cloud Infrastructure (OCI) Always Free AMD instance (`VM.Standard.E2.1.Micro`)**.

It handles isolated network creation, SSH key generation, and fault-domain cycling with adaptive jitter backoff out of the box.

---

## ⚡ Quick Start (One-Line Run)

1. Log in to your **Oracle Cloud Console**.
2. Click the **Cloud Shell** icon in the top-right header navigation.
3. Paste and run this command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hpfoo/oci-instance-hunter-amd/main/launch.sh)"
```

---

### 🔑 How SSH Keys Work (Beginner Guide)

If you are new to SSH or do not have a key, the script handles everything seamlessly without overriding existing credentials:

1. **Option 3 (Auto-Generate - Dedicated per Instance)**:
   - The script creates a dedicated, FIPS-compliant RSA 4096-bit key pair specifically named after your instance: `~/.ssh/<instance-name>_id_rsa`.
   - Running the script multiple times for different instances (ARM/AMD) will keep individual keys isolated.

2. **How to get the private key onto your local Mac / PC**:
   - **Method A (Copy-Paste Text)**: In Cloud Shell, run:
     ```bash
     cat ~/.ssh/<instance-name>_id_rsa
     ```
     Copy the entire block starting from `-----BEGIN OPENSSH PRIVATE KEY-----` to `-----END OPENSSH PRIVATE KEY-----`. Save it on your local machine (e.g., `~/.ssh/<instance-name>_key`) and set strict permissions:
     ```bash
     chmod 600 ~/.ssh/<instance-name>_key
     ```

   - **Method B (Download File via Web GUI)**: 
     Click the **Gear / Ellipsis icon** in the Cloud Shell top-right menu -> select **Download File** -> enter `.ssh/<instance-name>_id_rsa`.

3. **Connect to your server**:
   ```bash
   ssh -i ~/.ssh/<instance-name>_key ubuntu@<YOUR_PUBLIC_IP>
---

## 🕒 Running in Background (`tmux` - Optional)

Oracle Cloud Shell disconnects after 20 minutes of inactivity. To keep the script hunting 24/7 without terminal timeout:

1. Start a persistent tmux session:
   ```bash
   tmux new -s hunt-amd
   ```
2. Run the one-line command inside tmux:
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/hpfoo/oci-instance-hunter-amd/main/launch.sh)"
   ```
3. Detach safely: press `Ctrl + B`, then press `D`.

To check progress later:
```bash
tmux attach -t hunt-amd
```

---

## 🛠️ Architecture & Under the Hood

### Zero Impact on Existing Infrastructure
* Deploys an isolated VCN (`192.168.0.0/16`), custom Internet Gateway, dedicated Route Table (`0.0.0.0/0`), and a Public Subnet (`192.168.1.0/24`).
* Reuses the network if it already exists—safe to run multiple times without duplicating resources.

### Resource Specifications
* **Shape:** `VM.Standard.E2.1.Micro` (1 OCPU AMD x86_64, 1GB RAM)
* **Boot Volume:** 50 GB
* **OS Image:** Canonical Ubuntu 22.04 LTS (x86_64)

### Adaptive Capacity Hunting
* Automatically alternates across `FAULT-DOMAIN-1`, `FAULT-DOMAIN-2`, and `FAULT-DOMAIN-3`.
* Dynamic sleep intervals:
  * **Out of Host Capacity:** Randomized 40–81s jitter.
  * **API Rate Limits (429):** Randomized 108–162s backoff to avoid tenant-level API bans.

---

## 💻 Retrieve Public IP Manually

If you ever need to query your instance public IP again, run this in Cloud Shell:

```bash
oci compute instance list-vnics \
  --instance-id $(oci compute instance list --display-name "oci-amd-vm" --query "data[0].id" --raw-output) \
  --query 'data[0]."public-ip"' --raw-output
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
