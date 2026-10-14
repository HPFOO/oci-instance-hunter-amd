# 👨🏻‍💻 OCI Free Tier AMD Instance Hunter

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

## 🔑 Flexible SSH Key Management

The script gives you total flexibility with SSH credentials:
* **Default Auto-Detection:** Automatically detects existing keys at `~/.ssh/id_rsa.pub` or `~/.ssh/id_ed25519.pub`.
* **Custom Key Path:** Point directly to any custom file path (e.g., `~/.ssh/my_custom_key.pub` or `/tmp/uploaded_key.pub`).
* **Direct String:** Paste your public key string directly into the prompt.
* **Auto-Generation:** If you don't have a key, the script can auto-generate a brand-new ED25519 key pair on the fly without leaving Cloud Shell.

---

## 🕒 Running in Background (`tmux` - Optional)

Oracle Cloud Shell disconnects after 20 minutes of inactivity. If you plan to leave it hunting overnight without terminal timeout:

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

## 💻 SSH Connection After Provisioning

Once the script outputs `🎉 SUCCESS`, retrieve your public IP in Cloud Shell:

```bash
oci compute instance list-vnics \
  --instance-id $(oci compute instance list --display-name "oci-amd-vm" --query "data[0].id" --raw-output) \
  --query "data[0].\"public-ip\"" --raw-output
```

Connect directly:
```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<YOUR_PUBLIC_IP>
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.