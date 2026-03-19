#!/usr/bin/env bash
set -e

REPO_URL="git@github.com:malsonj/ai-orchestrator.git"
INSTALL_DIR="/opt/orchestrator"

echo "[ORCH] Installing orchestrator..."

if [ ! -d "$INSTALL_DIR" ]; then
    git clone $REPO_URL $INSTALL_DIR
else
    cd $INSTALL_DIR
    git pull
fi

cd $INSTALL_DIR

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
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python -m orchestrator.main
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable orchestrator.service
systemctl start orchestrator.service

echo "[ORCH] Orchestrator installed and running."
