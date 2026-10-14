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

## 🔑 How SSH Keys Work (Beginner Guide)

If you are new to SSH or do not have an SSH key prepared, the script handles the entire process:

### 1. Auto-Generation (Recommended for Beginners)
Select **Option 3** when prompted. The script automatically creates a clean, passwordless ED25519 key pair on the fly inside Cloud Shell at `~/.ssh/id_ed25519`.

### 2. How to Retrieve the Private Key onto Your Local Machine
Since the key was created inside Cloud Shell, you need the private key on your local machine (Mac / PC) to connect:

* **Method A (Copy-Paste Text - Recommended):**
  In Cloud Shell, display your private key:
  ```bash
  cat ~/.ssh/id_ed25519
  ```
  Copy the entire output (including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`), save it as a local file (e.g. `~/.ssh/oci_amd_key`), and restrict permissions:
  ```bash
  chmod 600 ~/.ssh/oci_amd_key
  ```

* **Method B (Download File via Cloud Shell GUI):**
  Click the **Gear / Ellipsis** icon in the top-right menu of Cloud Shell -> select **Download File** -> enter `/home/<your-user>/.ssh/id_ed25519`.

### 3. Connect to Your Server
```bash
ssh -i ~/.ssh/oci_amd_key ubuntu@<YOUR_PUBLIC_IP>
```

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
