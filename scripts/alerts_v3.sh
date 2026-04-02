#!/bin/bash
# ==========================================================
# 📢 ALERTS V3: DISCORD NOTIFICATION HELPER
# ==========================================================

WEBHOOK_FILE="/etc/xdpfw/webhook.txt"
WEBHOOK_URL=$(cat "$WEBHOOK_FILE" 2>/dev/null)

if [ -z "$WEBHOOK_URL" ]; then
    exit 0
fi

TITLE=$1
MESSAGE=$2
COLOR=$3 # 3066993 (Blue), 15158332 (Red), 3066993 (Green)

[ -z "$COLOR" ] && COLOR=3066993

HOSTNAME=$(hostname)
IP_SERVER=$(curl -s https://api.ipify.org || echo "Unknown")

PAYLOAD=$(cat <<EOF
{
  "embeds": [
    {
      "title": "🛡️ $TITLE",
      "description": "$MESSAGE",
      "color": $COLOR,
      "fields": [
        { "name": "🖥️ Server", "value": "$HOSTNAME ($IP_SERVER)", "inline": true },
        { "name": "⏰ Time", "value": "$(date '+%Y-%m-%d %H:%M:%S')", "inline": true }
      ],
      "footer": { "text": "Anti-DDoS V3 Ultimate Guardian" }
    }
  ]
}
EOF
)

curl -s -H "Content-Type: application/json" -X POST -d "$PAYLOAD" "$WEBHOOK_URL" > /dev/null
