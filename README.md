# Auto-Healing Website with CI/CD Deployment on AWS (EC2 Free Tier)

Beginner-friendly real-world DevOps project:

- **Backend**: Python Flask
- **Container**: Docker (Gunicorn)
- **CI/CD**: GitHub Actions
- **Cloud**: AWS EC2 (Ubuntu)
- **Auto-heal**: Bash monitor script + cron (restarts container if `/health` fails)

---

## Folder structure

```
cicd/
  app/
    app.py
    templates/
      index.html
    static/
      styles.css
  scripts/
    monitor.sh
    install_cron.sh
  .github/
    workflows/
      deploy.yml
  Dockerfile
  requirements.txt
  .dockerignore
  README.md
```

---

## What you built

- `GET /` → Attractive landing page
- `GET /health` → Returns `{"status":"OK"}`

---

## Run locally (Windows) using Docker

### 1) Start Docker Desktop + set context

In PowerShell:

```powershell
docker context use desktop-linux
docker info
```

If `docker info` shows **Server:** details, Docker is ready.

### 2) Build + run

```powershell
Set-Location "C:\Users\Rohit\OneDrive\Desktop\cicd"

docker build -t autoheal-flask:local .

# Run on port 8080 (no admin needed)
docker rm -f autoheal-flask 2>$null | Out-Null
docker run -d --name autoheal-flask -p 8080:5000 autoheal-flask:local
```

### 3) Test

```powershell
curl.exe -fsS http://localhost:8080/health
Start-Process "http://localhost:8080/"
```

---

## Deploy to AWS EC2 (Ubuntu) — step-by-step

### 0) Create an EC2 instance (Free Tier)

- **AMI**: Ubuntu Server 22.04 LTS (or 24.04 LTS)
- **Instance type**: `t2.micro` / `t3.micro` (Free Tier eligible depending on your account)
- **Key pair**: create/download `.pem`

### 1) Security Group (important)

Allow inbound:

- **HTTP**: TCP `80` from `0.0.0.0/0`
- **SSH**: TCP `22` from **your IP** (recommended)

### 2) SSH into EC2

From your local machine:

```bash
ssh -i /path/to/your-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
```

### 3) Install Docker on EC2

On EC2:

```bash
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

Quick check:

```bash
docker --version
sudo docker ps
```

### 4) First-time deploy (manual)

On EC2, create a project folder:

```bash
mkdir -p ~/app
cd ~/app
```

You have two beginner-friendly options:

#### Option A (recommended): Deploy via GitHub Actions (CI/CD)

Follow the **CI/CD** section below. Once secrets are set, just push to `main`.

#### Option B: Manual build on EC2 (simple, no CI/CD yet)

If your repo is on GitHub:

```bash
sudo apt-get install -y git
git clone YOUR_REPO_GIT_URL
cd YOUR_REPO_FOLDER
sudo docker build -t autoheal-flask:latest .
sudo docker rm -f autoheal-flask || true
sudo docker run -d --restart unless-stopped --name autoheal-flask -p 80:5000 autoheal-flask:latest
curl -fsS http://127.0.0.1/health
```

Now open in browser:

- `http://YOUR_EC2_PUBLIC_IP/`

---

## Auto-healing (monitor script + cron) on EC2

### 1) Copy scripts to EC2

If you cloned the repo on EC2, they’re already there in `scripts/`.

### 2) Make scripts executable

On EC2 (inside repo folder):

```bash
chmod +x scripts/monitor.sh scripts/install_cron.sh
```

### 3) Test the monitor manually

```bash
sudo APP_URL=http://127.0.0.1/health CONTAINER_NAME=autoheal-flask IMAGE_NAME=autoheal-flask:latest ./scripts/monitor.sh
```

### 4) Install cron (runs every minute)

```bash
sudo bash scripts/install_cron.sh
```

Check that cron is installed:

```bash
sudo crontab -l
```

View logs:

```bash
sudo tail -n 200 /var/log/autoheal-monitor.log
```

---

## CI/CD with GitHub Actions → Auto deploy to EC2

This repo includes: `.github/workflows/deploy.yml`

### How it deploys (simple approach)

- GitHub Actions builds the Docker image
- Exports it as `autoheal-flask-image.tar.gz`
- Copies it to EC2 over SSH/SCP
- Loads the image on EC2 and re-runs the container

### 1) Create SSH key for GitHub Actions

On your **local machine**:

```bash
ssh-keygen -t ed25519 -C "github-actions-ec2" -f github_actions_ec2 -N ""
```

- `github_actions_ec2` → private key (keep secret)
- `github_actions_ec2.pub` → public key

### 2) Add public key to EC2

On EC2:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "PASTE_CONTENTS_OF_github_actions_ec2.pub_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 3) Add GitHub Secrets

In your GitHub repo:
**Settings → Secrets and variables → Actions → New repository secret**

Add:

- **`EC2_HOST`**: `YOUR_EC2_PUBLIC_IP` (or DNS)
- **`EC2_USER`**: `ubuntu`
- **`EC2_PORT`**: `22`
- **`EC2_SSH_KEY`**: paste the **private key** file contents (`github_actions_ec2`)

### 4) Prepare EC2 deploy folder (one-time)

On EC2:

```bash
mkdir -p ~/deploy
```

### 5) Push to `main`

Every push to `main` triggers deployment.

---

## Prove auto-healing works (failure test)

### On EC2 (best demo)

1) Confirm website is up:

```bash
curl -fsS http://127.0.0.1/health
```

2) Force failure:

```bash
sudo docker stop autoheal-flask
```

3) Wait ~1 minute (cron runs monitor every minute), then verify it recovered:

```bash
curl -fsS http://127.0.0.1/health
sudo docker ps --filter "name=autoheal-flask"
sudo tail -n 50 /var/log/autoheal-monitor.log
```

You should see logs like:

- `Health FAILED ... Attempting auto-heal...`
- `Auto-heal SUCCESS ...`

---

## Common errors and fixes

### Local (Windows)

- **Docker engine not reachable / pipe missing**
  - Fix: Start Docker Desktop, then run:

```powershell
docker context use desktop-linux
docker info
```

- **Port already in use (8080)**
  - Fix: use another port:

```powershell
docker rm -f autoheal-flask 2>$null | Out-Null
docker run -d --name autoheal-flask -p 8081:5000 autoheal-flask:local
```

- **You rebuilt but still see old page**
  - Fix: rebuild + recreate container (not just restart):

```powershell
docker build -t autoheal-flask:local .
docker rm -f autoheal-flask 2>$null | Out-Null
docker run -d --name autoheal-flask -p 8080:5000 autoheal-flask:local
```

### EC2 (Ubuntu)

- **Site not reachable from browser**
  - Fix: Security Group must allow inbound TCP `80` from `0.0.0.0/0`.
  - Also ensure container mapping is `-p 80:5000`.

- **`Permission denied` running docker**
  - Easiest fix: prefix with `sudo docker ...`

- **Cron runs but doesn’t restart**
  - Check logs: `sudo tail -n 200 /var/log/autoheal-monitor.log`
  - Ensure scripts are executable: `chmod +x scripts/*.sh`

---

## Next steps (recommended order)

1) Local Docker run (you already did)
2) Launch EC2 + install Docker
3) Manual deploy once on EC2 (sanity check)
4) Install cron auto-heal
5) Add GitHub Secrets + push to `main` to enable CI/CD

