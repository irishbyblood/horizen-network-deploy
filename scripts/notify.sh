#!/bin/bash

# Horizen Network Notification Script
# Supports Slack, Discord, and Email notifications

set -e

# Load environment variables
if [ -f .env ]; then
    source .env 2>/dev/null || true
fi

# Configuration
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL:-}"
EMAIL_TO="${NOTIFICATION_EMAIL:-}"
EMAIL_FROM="${NOTIFICATION_FROM_EMAIL:-noreply@horizen-network.com}"
HOSTNAME=$(hostname)

# Color codes for different event types
COLOR_SUCCESS="good"      # green
COLOR_ERROR="danger"      # red
COLOR_WARNING="warning"   # yellow
COLOR_INFO="#439FE0"      # blue

# Function to get color and emoji based on event type
get_notification_style() {
    local event_type="$1"
    
    case "$event_type" in
        *success*)
            echo "success|✅|$COLOR_SUCCESS"
            ;;
        *failed*|*error*)
            echo "error|❌|$COLOR_ERROR"
            ;;
        *warning*)
            echo "warning|⚠️|$COLOR_WARNING"
            ;;
        *started*|*info*)
            echo "info|ℹ️|$COLOR_INFO"
            ;;
        *security*)
            echo "security|🔒|$COLOR_ERROR"
            ;;
        *)
            echo "info|📢|$COLOR_INFO"
            ;;
    esac
}

# Function to generate message template
generate_message() {
    local event_type="$1"
    local message="$2"
    local details="${3:-}"
    
    IFS='|' read -r status emoji color <<< "$(get_notification_style "$event_type")"
    
    local title=""
    case "$event_type" in
        deployment_started)
            title="🚀 Deployment Started"
            ;;
        deployment_completed)
            title="✅ Deployment Completed"
            ;;
        deployment_failed)
            title="❌ Deployment Failed"
            ;;
        backup_success)
            title="✅ Backup Completed"
            ;;
        backup_failed)
            title="❌ Backup Failed"
            ;;
        health_check_failed)
            title="⚠️ Health Check Failed"
            ;;
        security_alert)
            title="🔒 Security Alert"
            ;;
        *)
            title="$emoji Horizen Network Notification"
            ;;
    esac
    
    echo "$title|$message|$details|$color|$emoji"
}

# Function to send Slack notification
send_slack_notification() {
    local event_type="$1"
    local message="$2"
    local details="${3:-}"
    
    if [ -z "$SLACK_WEBHOOK" ]; then
        return 0
    fi
    
    IFS='|' read -r title msg det color emoji <<< "$(generate_message "$event_type" "$message" "$details")"
    
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    # Build Slack message payload
    local payload=$(cat <<EOF
{
  "username": "Horizen Network Bot",
  "icon_emoji": ":robot_face:",
  "attachments": [
    {
      "color": "$color",
      "title": "$title",
      "text": "$msg",
      "fields": [
        {
          "title": "Host",
          "value": "$HOSTNAME",
          "short": true
        },
        {
          "title": "Time",
          "value": "$timestamp",
          "short": true
        }
      ],
      "footer": "Horizen Network Monitoring",
      "footer_icon": "https://platform.slack-edge.com/img/default_application_icon.png"
    }
  ]
}
EOF
)
    
    if [ -n "$details" ]; then
        payload=$(echo "$payload" | jq --arg det "$details" '.attachments[0].fields += [{"title":"Details","value":$det,"short":false}]')
    fi
    
    # Send to Slack
    if curl -X POST -H 'Content-type: application/json' \
        --data "$payload" \
        "$SLACK_WEBHOOK" \
        -s -o /dev/null -w "%{http_code}" | grep -q "200"; then
        echo "✓ Slack notification sent"
        return 0
    else
        echo "✗ Failed to send Slack notification"
        return 1
    fi
}

# Function to send Discord notification
send_discord_notification() {
    local event_type="$1"
    local message="$2"
    local details="${3:-}"
    
    if [ -z "$DISCORD_WEBHOOK" ]; then
        return 0
    fi
    
    IFS='|' read -r title msg det color emoji <<< "$(generate_message "$event_type" "$message" "$details")"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Convert Slack color to Discord decimal color
    local discord_color
    case "$color" in
        "good") discord_color=3066993 ;;      # green
        "danger") discord_color=15158332 ;;   # red
        "warning") discord_color=16776960 ;;  # yellow
        *) discord_color=4886754 ;;           # blue
    esac
    
    # Build Discord embed payload
    local payload=$(cat <<EOF
{
  "username": "Horizen Network Bot",
  "avatar_url": "https://i.imgur.com/4M34hi2.png",
  "embeds": [
    {
      "title": "$title",
      "description": "$msg",
      "color": $discord_color,
      "fields": [
        {
          "name": "Host",
          "value": "$HOSTNAME",
          "inline": true
        },
        {
          "name": "Time",
          "value": "$timestamp",
          "inline": true
        }
      ],
      "footer": {
        "text": "Horizen Network Monitoring"
      },
      "timestamp": "$timestamp"
    }
  ]
}
EOF
)
    
    if [ -n "$details" ]; then
        payload=$(echo "$payload" | jq --arg det "$details" '.embeds[0].fields += [{"name":"Details","value":$det,"inline":false}]')
    fi
    
    # Send to Discord
    if curl -X POST -H 'Content-Type: application/json' \
        --data "$payload" \
        "$DISCORD_WEBHOOK" \
        -s -o /dev/null -w "%{http_code}" | grep -q "204"; then
        echo "✓ Discord notification sent"
        return 0
    else
        echo "✗ Failed to send Discord notification"
        return 1
    fi
}

# Function to send email notification
send_email_notification() {
    local event_type="$1"
    local message="$2"
    local details="${3:-}"
    
    if [ -z "$EMAIL_TO" ]; then
        return 0
    fi
    
    if ! command -v mail &> /dev/null && ! command -v sendmail &> /dev/null; then
        echo "⚠ Email client not found, skipping email notification"
        return 1
    fi
    
    IFS='|' read -r title msg det color emoji <<< "$(generate_message "$event_type" "$message" "$details")"
    
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    # Build email body
    local email_body=$(cat <<EOF
$title

Message: $msg

Host: $HOSTNAME
Time: $timestamp

$([ -n "$details" ] && echo "Details: $details")

---
Horizen Network Monitoring System
EOF
)
    
    # Send email
    if command -v mail &> /dev/null; then
        echo "$email_body" | mail -s "$title" -r "$EMAIL_FROM" "$EMAIL_TO"
        echo "✓ Email notification sent"
        return 0
    elif command -v sendmail &> /dev/null; then
        (
            echo "From: $EMAIL_FROM"
            echo "To: $EMAIL_TO"
            echo "Subject: $title"
            echo ""
            echo "$email_body"
        ) | sendmail -t
        echo "✓ Email notification sent via sendmail"
        return 0
    fi
    
    return 1
}

# Main notification function
send_notification() {
    local event_type="$1"
    local message="$2"
    local details="${3:-}"
    
    echo "Sending notifications for: $event_type"
    
    local success=0
    
    # Send to all configured channels
    if [ -n "$SLACK_WEBHOOK" ]; then
        send_slack_notification "$event_type" "$message" "$details" && ((success++)) || true
    fi
    
    if [ -n "$DISCORD_WEBHOOK" ]; then
        send_discord_notification "$event_type" "$message" "$details" && ((success++)) || true
    fi
    
    if [ -n "$EMAIL_TO" ]; then
        send_email_notification "$event_type" "$message" "$details" && ((success++)) || true
    fi
    
    if [ $success -eq 0 ]; then
        echo "⚠ No notification channels configured or all failed"
        echo "Configure SLACK_WEBHOOK_URL, DISCORD_WEBHOOK_URL, or NOTIFICATION_EMAIL in .env"
        return 1
    fi
    
    return 0
}

# Usage information
usage() {
    cat <<EOF
Usage: $0 <event_type> <message> [details]

Event Types:
  - deployment_started
  - deployment_completed
  - deployment_failed
  - backup_success
  - backup_failed
  - health_check_failed
  - security_alert

Example:
  $0 backup_success "Daily backup completed" "Size: 1.2GB, Duration: 5m"

Configuration (in .env file):
  SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
  DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR/WEBHOOK/URL
  NOTIFICATION_EMAIL=admin@example.com
EOF
}

# Main execution
if [ $# -lt 2 ]; then
    usage
    exit 1
fi

EVENT_TYPE="$1"
MESSAGE="$2"
DETAILS="${3:-}"

send_notification "$EVENT_TYPE" "$MESSAGE" "$DETAILS"
