#!/bin/zsh

###
# Core MINERTIMER script. Kills minecraft Java edition on MacOS after 30 min.
# Developed and owned by Soferio Pty Limited.
###

# Time limits (in seconds)
TIME_LIMIT=1800
WEEKEND_TIME_LIMIT=3600
DISPLAY_5_MIN_WARNING=true
DISPLAY_1_MIN_WARNING=true

# Base directory for logs
LOG_DIRECTORY="/var/lib/minertimer"

# Ensure the log directory exists with root permissions
mkdir -p $LOG_DIRECTORY
chmod 700 $LOG_DIRECTORY

while true; do
    # Get Minecraft and Roblox processes, filtering to avoid grep process itself
    PROCESS_LIST=$(ps aux | grep -iwwE "[M]inecraft|[R]oblox")

    # Extract unique users who are running the processes
    USERS=($(echo "$PROCESS_LIST" | awk '{print $1}' | sort -u))

    for USER in "${USERS[@]}"; do
        if [ -z "$USER" ]; then
            continue
        fi

        # Set up user's log file location
        USER_LOG_DIR="$LOG_DIRECTORY/$USER"
        USER_LOG_FILE="$USER_LOG_DIR/minertimer_playtime.log"

        # Ensure user's log directory exists and is owned by root
        sudo mkdir -p "$USER_LOG_DIR"
        sudo chown root:wheel "$USER_LOG_DIR"
        sudo chmod 700 "$USER_LOG_DIR"

        # Get current date
        CURRENT_DATE=$(date +%Y-%m-%d)

        # Initialize log file if it doesn't exist
        if [ ! -f "$USER_LOG_FILE" ]; then
            echo "$CURRENT_DATE" | sudo tee "$USER_LOG_FILE" > /dev/null
            echo "0" | sudo tee -a "$USER_LOG_FILE" > /dev/null
        fi

        # Read the last play date and total played time from the log
        LAST_PLAY_DATE=$(head -n 1 "$USER_LOG_FILE")
        TOTAL_PLAYED_TIME=$(tail -n 1 "$USER_LOG_FILE")

        # Reset playtime if it's a new day
        if [ "$LAST_PLAY_DATE" != "$CURRENT_DATE" ]; then
            TOTAL_PLAYED_TIME=0
            echo "$CURRENT_DATE" | sudo tee "$USER_LOG_FILE" > /dev/null
            echo "0" | sudo tee -a "$USER_LOG_FILE" > /dev/null
        fi

        # Determine if weekend limit should apply
        current_limit=$TIME_LIMIT
        if [[ $(date +%u) -gt 5 ]]; then
            current_limit=$WEEKEND_TIME_LIMIT
        fi

        # Get process IDs for the current user
        USER_PIDS=$(echo "$PROCESS_LIST" | awk -v user="$USER" '$1 == user {print $2}')

        if [ -n "$USER_PIDS" ]; then
            if ((TOTAL_PLAYED_TIME >= current_limit)); then
                echo $USER_PIDS | xargs sudo kill
                echo "Minecraft and Roblox for $USER have been closed after reaching the daily time limit."
                sudo -u "$USER" osascript -e 'display notification "Minecraft and Roblox time expired" with title "Time Up!"'
                afplay /System/Library/Sounds/Glass.aiff 
            elif ((TOTAL_PLAYED_TIME >= current_limit - 300)) && [ "$DISPLAY_5_MIN_WARNING" = true ]; then
                sudo -u "$USER" osascript -e 'display notification "Minecraft and Roblox will exit in 5 minutes" with title "Time Expiring Soon"'
                sudo -u "$USER" say "Minecraft and Roblox time will expire in 5 minutes"
                DISPLAY_5_MIN_WARNING=false
            elif ((TOTAL_PLAYED_TIME >= current_limit - 60)) && [ "$DISPLAY_1_MIN_WARNING" = true ]; then
                sudo -u "$USER" osascript -e 'display notification "Minecraft and Roblox will exit in 1 minute" with title "Time Expiring"'
                sudo -u "$USER" say "Minecraft and Roblox time will expire in 1 minute"
                DISPLAY_1_MIN_WARNING=false
            fi

            # Sleep, then increment the playtime
            sleep 20
            TOTAL_PLAYED_TIME=$((TOTAL_PLAYED_TIME + 20))

            # Update the log file securely
            sudo sed -i '' "$ s/.*/$TOTAL_PLAYED_TIME/" "$USER_LOG_FILE"
        else
            sleep 10
        fi

        # Recheck the current date and reset playtime if needed
        CURRENT_DATE=$(date +%Y-%m-%d)
        LAST_PLAY_DATE=$(head -n 1 "$USER_LOG_FILE")

        if [ "$LAST_PLAY_DATE" != "$CURRENT_DATE" ]; then
            TOTAL_PLAYED_TIME=0
            DISPLAY_5_MIN_WARNING=true
            DISPLAY_1_MIN_WARNING=true
            echo "$CURRENT_DATE" | sudo tee "$USER_LOG_FILE" > /dev/null
            echo "0" | sudo tee -a "$USER_LOG_FILE" > /dev/null
            echo "Playtime reset for $USER - $CURRENT_DATE"
        fi
    done
done