#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/malsonj/ai-orchestrator.git"
INSTALL_DIR="/opt/orchestrator"

echo "[ORCH] Installing orchestrator..."

if [ ! -d "" ]; then
    git clone \ \
else
    cd \
    git pull
fi

cd \

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install -e .

cat <<EOF >/etc/systemd/system/orchestrator.service
[Unit]
Description=AI Orchestrator
After=network.target

[Service]
Type=simple
User=agent
WorkingDirectory=\
ExecStart=\/venv/bin/python -m orchestrator.main
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable orchestrator.service
systemctl start orchestrator.service

echo "[ORCH] Orchestrator installed and running."

# Auto-update on reboot
cat <<EOF >/etc/systemd/system/orchestrator-update.service
[Unit]
Description=Auto-update orchestrator
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/git -C /opt/orchestrator pull

[Install]
WantedBy=multi-user.target
EOF

systemctl enable orchestrator-update.service
