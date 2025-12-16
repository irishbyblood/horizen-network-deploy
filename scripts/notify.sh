#!/bin/bash

# Horizen Network Notification Script
# Sends notifications to Slack, Discord, or Email

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NOTIFICATION_TYPE="info"
MESSAGE=""
TITLE="Horizen Network Notification"
SEND_SLACK=false
SEND_DISCORD=false
SEND_EMAIL=false

# Load environment variables if available
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --message MESSAGE    Notification message (required)"
    echo "  -t, --title TITLE        Notification title (default: Horizen Network Notification)"
    echo "  -s, --status STATUS      Status: success|warning|error|info (default: info)"
    echo "  -S, --slack              Send to Slack"
    echo "  -D, --discord            Send to Discord"
    echo "  -E, --email              Send via Email"
    echo "  -a, --all                Send to all configured channels"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Environment Variables (set in .env or export):"
    echo "  SLACK_WEBHOOK_URL        Slack webhook URL"
    echo "  DISCORD_WEBHOOK_URL      Discord webhook URL"
    echo "  SMTP_HOST                SMTP server host"
    echo "  SMTP_PORT                SMTP server port (default: 587)"
    echo "  SMTP_USER                SMTP username"
    echo "  SMTP_PASSWORD            SMTP password"
    echo "  SMTP_FROM                From email address"
    echo "  SMTP_TO                  To email address(es)"
    echo ""
    echo "Examples:"
    echo "  $0 -m 'Deployment successful' -s success --slack"
    echo "  $0 -m 'High CPU usage' -s warning --all"
    echo "  $0 -t 'Backup Failed' -m 'Backup job failed' -s error --email"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--message)
            MESSAGE="$2"
            shift 2
            ;;
        -t|--title)
            TITLE="$2"
            shift 2
            ;;
        -s|--status)
            NOTIFICATION_TYPE="$2"
            shift 2
            ;;
        -S|--slack)
            SEND_SLACK=true
            shift
            ;;
        -D|--discord)
            SEND_DISCORD=true
            shift
            ;;
        -E|--email)
            SEND_EMAIL=true
            shift
            ;;
        -a|--all)
            SEND_SLACK=true
            SEND_DISCORD=true
            SEND_EMAIL=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$MESSAGE" ]; then
    echo -e "${RED}Error: Message is required${NC}"
    usage
fi

# Validate notification type
case $NOTIFICATION_TYPE in
    success|warning|error|info)
        ;;
    *)
        echo -e "${RED}Error: Invalid status. Must be: success, warning, error, or info${NC}"
        exit 1
        ;;
esac

# Set color and emoji based on type
case $NOTIFICATION_TYPE in
    success)
        COLOR="#28a745"
        EMOJI="✅"
        ;;
    warning)
        COLOR="#ffc107"
        EMOJI="⚠️"
        ;;
    error)
        COLOR="#dc3545"
        EMOJI="❌"
        ;;
    info)
        COLOR="#17a2b8"
        EMOJI="ℹ️"
        ;;
esac

# Get timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Get hostname
HOSTNAME=$(hostname)

# Function to send Slack notification
send_slack() {
    if [ -z "$SLACK_WEBHOOK_URL" ]; then
        echo -e "${YELLOW}Slack webhook URL not configured${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Sending notification to Slack...${NC}"
    
    # Prepare Slack payload
    SLACK_PAYLOAD=$(cat <<EOF
{
    "attachments": [
        {
            "color": "$COLOR",
            "title": "$EMOJI $TITLE",
            "text": "$MESSAGE",
            "fields": [
                {
                    "title": "Status",
                    "value": "$NOTIFICATION_TYPE",
                    "short": true
                },
                {
                    "title": "Host",
                    "value": "$HOSTNAME",
                    "short": true
                }
            ],
            "footer": "Horizen Network",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    # Send to Slack
    RESPONSE=$(curl -s -X POST -H 'Content-type: application/json' \
        --data "$SLACK_PAYLOAD" \
        "$SLACK_WEBHOOK_URL")
    
    if [ "$RESPONSE" = "ok" ]; then
        echo -e "${GREEN}✓ Slack notification sent${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to send Slack notification: $RESPONSE${NC}"
        return 1
    fi
}

# Function to send Discord notification
send_discord() {
    if [ -z "$DISCORD_WEBHOOK_URL" ]; then
        echo -e "${YELLOW}Discord webhook URL not configured${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Sending notification to Discord...${NC}"
    
    # Convert hex color to decimal
    COLOR_DEC=$(printf "%d" "0x${COLOR#\#}")
    
    # Prepare Discord payload
    DISCORD_PAYLOAD=$(cat <<EOF
{
    "embeds": [
        {
            "title": "$EMOJI $TITLE",
            "description": "$MESSAGE",
            "color": $COLOR_DEC,
            "fields": [
                {
                    "name": "Status",
                    "value": "$NOTIFICATION_TYPE",
                    "inline": true
                },
                {
                    "name": "Host",
                    "value": "$HOSTNAME",
                    "inline": true
                },
                {
                    "name": "Timestamp",
                    "value": "$TIMESTAMP",
                    "inline": false
                }
            ],
            "footer": {
                "text": "Horizen Network"
            }
        }
    ]
}
EOF
)
    
    # Send to Discord
    RESPONSE=$(curl -s -X POST -H 'Content-type: application/json' \
        --data "$DISCORD_PAYLOAD" \
        "$DISCORD_WEBHOOK_URL")
    
    if [ -z "$RESPONSE" ]; then
        echo -e "${GREEN}✓ Discord notification sent${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to send Discord notification: $RESPONSE${NC}"
        return 1
    fi
}

# Function to send Email notification
send_email() {
    if [ -z "$SMTP_HOST" ] || [ -z "$SMTP_USER" ] || [ -z "$SMTP_PASSWORD" ] || [ -z "$SMTP_FROM" ] || [ -z "$SMTP_TO" ]; then
        echo -e "${YELLOW}Email configuration incomplete${NC}"
        echo -e "${YELLOW}Required: SMTP_HOST, SMTP_USER, SMTP_PASSWORD, SMTP_FROM, SMTP_TO${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Sending email notification...${NC}"
    
    # Set default SMTP port if not specified
    SMTP_PORT=${SMTP_PORT:-587}
    
    # Prepare email content
    EMAIL_SUBJECT="$EMOJI $TITLE - $NOTIFICATION_TYPE"
    EMAIL_BODY=$(cat <<EOF
Horizen Network Notification

Title: $TITLE
Status: $NOTIFICATION_TYPE
Timestamp: $TIMESTAMP
Host: $HOSTNAME

Message:
$MESSAGE

---
This is an automated notification from Horizen Network monitoring system.
EOF
)
    
    # Check if mailx is available
    if command -v mailx >/dev/null 2>&1; then
        # Use mailx
        echo "$EMAIL_BODY" | mailx -s "$EMAIL_SUBJECT" \
            -S smtp="$SMTP_HOST:$SMTP_PORT" \
            -S smtp-use-starttls \
            -S smtp-auth=login \
            -S smtp-auth-user="$SMTP_USER" \
            -S smtp-auth-password="$SMTP_PASSWORD" \
            -S from="$SMTP_FROM" \
            "$SMTP_TO" 2>/dev/null && {
            echo -e "${GREEN}✓ Email notification sent${NC}"
            return 0
        } || {
            echo -e "${RED}✗ Failed to send email notification${NC}"
            return 1
        }
    elif command -v sendmail >/dev/null 2>&1; then
        # Use sendmail
        {
            echo "From: $SMTP_FROM"
            echo "To: $SMTP_TO"
            echo "Subject: $EMAIL_SUBJECT"
            echo ""
            echo "$EMAIL_BODY"
        } | sendmail -t && {
            echo -e "${GREEN}✓ Email notification sent${NC}"
            return 0
        } || {
            echo -e "${RED}✗ Failed to send email notification${NC}"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        # Use curl with SMTP
        CURL_EMAIL=$(cat <<EOF
From: $SMTP_FROM
To: $SMTP_TO
Subject: $EMAIL_SUBJECT

$EMAIL_BODY
EOF
)
        
        echo "$CURL_EMAIL" | curl -s --url "smtp://$SMTP_HOST:$SMTP_PORT" \
            --ssl \
            --mail-from "$SMTP_FROM" \
            --mail-rcpt "$SMTP_TO" \
            --user "$SMTP_USER:$SMTP_PASSWORD" \
            --upload-file - && {
            echo -e "${GREEN}✓ Email notification sent${NC}"
            return 0
        } || {
            echo -e "${RED}✗ Failed to send email notification${NC}"
            return 1
        }
    else
        echo -e "${RED}No email client available (mailx, sendmail, or curl required)${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}=== Horizen Network Notification ===${NC}"
    echo -e "Title: $TITLE"
    echo -e "Message: $MESSAGE"
    echo -e "Status: $NOTIFICATION_TYPE"
    echo ""
    
    SUCCESS=0
    FAILURES=0
    
    # Send to Slack if requested
    if [ "$SEND_SLACK" = true ]; then
        if send_slack; then
            ((SUCCESS++))
        else
            ((FAILURES++))
        fi
    fi
    
    # Send to Discord if requested
    if [ "$SEND_DISCORD" = true ]; then
        if send_discord; then
            ((SUCCESS++))
        else
            ((FAILURES++))
        fi
    fi
    
    # Send Email if requested
    if [ "$SEND_EMAIL" = true ]; then
        if send_email; then
            ((SUCCESS++))
        else
            ((FAILURES++))
        fi
    fi
    
    # Check if any notification method was selected
    if [ "$SEND_SLACK" = false ] && [ "$SEND_DISCORD" = false ] && [ "$SEND_EMAIL" = false ]; then
        echo -e "${YELLOW}No notification method selected${NC}"
        echo -e "${YELLOW}Use --slack, --discord, --email, or --all${NC}"
        exit 1
    fi
    
    # Summary
    echo ""
    echo -e "${BLUE}=== Notification Summary ===${NC}"
    echo -e "Successful: $SUCCESS"
    echo -e "Failed: $FAILURES"
    
    if [ $FAILURES -eq 0 ]; then
        echo -e "${GREEN}✓ All notifications sent successfully${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some notifications failed${NC}"
        exit 1
    fi
}

# Run main function
main
