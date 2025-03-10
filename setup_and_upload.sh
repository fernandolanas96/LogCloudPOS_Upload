#!/data/data/com.termux/files/usr/bin/bash

# Configuration variables (replace with your own details)
RCLONE_REMOTE_NAME="gdrive"
CLIENT_ID="clientId"
CLIENT_SECRET="clientsecret"

# Define local and remote directories
LOCAL_DIR="/storage/emulated/0/Android/data/com.valet_manager.pointofsale/logs/" # Change this to the desired local directory
REMOTE_PARENT="gdrive:/Logs_Backup" # Change this to the desired parent directory in Google Drive, the script creates an automatic folder in gdrive, no need to create it in gdrive in advanced

# Customizable variables for folder and remote directory
FOLDER_NAME="PPS_100"  # Change this to the desired folder name
REMOTE_DIR="$REMOTE_PARENT/$FOLDER_NAME"
RCLONE_CONF="$HOME/.config/rclone/rclone.conf"

Function to manage crond process
manage_crond() {
    echo "🔄 Managing crond process..."

    # Check if crond is already running
    if pgrep crond > /dev/null; then
        echo "🔍 crond is already running. Killing it..."
        pkill crond
        sleep 1  # Wait for the process to terminate
    fi

    # Remove stale PID file if it exists
    PID_FILE="/data/data/com.termux/files/usr/var/run/crond.pid"
    if [ -f "$PID_FILE" ]; then
        echo "🗑 Removing stale PID file: $PID_FILE"
        rm -f "$PID_FILE"
    fi

    # Start crond
    echo "🚀 Starting crond..."
    crond
    if [ $? -eq 0 ]; then
        echo "✅ crond started successfully!"
    else
        echo "❌ Failed to start crond. Please check the logs."
        exit 1
    fi
}

# Function to check and refresh the rclone token with debugging
refresh_rclone_token() {
    echo "🔍 Checking rclone token status..."

    # Debug: Log the current state of rclone.conf
    echo "🔍 Current rclone.conf content:"
    cat "$RCLONE_CONF"

    # Check if the token is valid
    if ! rclone lsf "$RCLONE_REMOTE_NAME:" > /dev/null 2>&1; then
        echo "🔄 Token expired or invalid. Refreshing token..."

        # Remove the existing rclone.conf file
        if [ -f "$RCLONE_CONF" ]; then
            echo "🗑 Removing existing rclone.conf file..."
            rm -f "$RCLONE_CONF"
        fi

        # Debug: Log after removal
        echo "🔍 rclone.conf after removal:"
        ls -l "$RCLONE_CONF"

        # Create a new rclone.conf file
        echo "📄 Creating new rclone.conf file..."
        mkdir -p "$(dirname "$RCLONE_CONF")"
        cat <<EOF > "$RCLONE_CONF"
[$RCLONE_REMOTE_NAME]
type = drive
client_id = $CLIENT_ID
client_secret = $CLIENT_SECRET
scope = drive
token = {"access_token":""}
EOF

        # Debug: Log after creation
        echo "🔍 rclone.conf after creation:"
        cat "$RCLONE_CONF"

        # Use port 53682 for the auth webserver
        export RCLONE_AUTH_PROXY_LISTEN=127.0.0.1:53682

        # Attempt to refresh the token
        if rclone config reconnect "$RCLONE_REMOTE_NAME:" --auto-confirm; then
            echo "✅ Token refreshed successfully!"

            # Debug: Log the contents of rclone.conf
            echo "🔍 Debugging rclone.conf file..."
            cat "$RCLONE_CONF"

            # Debug: Extract and log the token details
            if command -v jq > /dev/null; then
                echo "🔍 Extracting token details..."
                TOKEN=$(grep -oP '"token":\s*\K[^,]+' "$RCLONE_CONF" | tr -d '\\')
                if [ -n "$TOKEN" ]; then
                    echo "🔍 Token details:"
                    echo "$TOKEN" | jq .
                else
                    echo "❌ Failed to extract token details."
                fi
            else
                echo "❌ jq is not installed. Install it with 'pkg install jq' to debug token details."
            fi
        else
            echo "❌ Failed to refresh token. Killing existing rclone processes and retrying..."

            # Kill any existing rclone processes
            pkill rclone
            sleep 1  # Wait for the processes to terminate

            # Clear rclone cache
            rm -rf ~/.cache/rclone

            # Retry refreshing the token
            if rclone config reconnect "$RCLONE_REMOTE_NAME:" --auto-confirm; then
                echo "✅ Token refreshed successfully after killing existing processes!"
            else
                echo "❌ Failed to refresh token even after killing processes. Please check your configuration."
                exit 1
            fi
        fi
    else
        echo "✅ Token is valid."
    fi
}

# Function to setup and configure tools
setup_tools() {
    echo "🔄 Updating & upgrading Termux..."
    pkg update -y && pkg upgrade -y

    echo "📦 Installing required packages..."
    pkg install -y git curl file rclone jq openssl cronie htop

    echo "📂 Setting up storage permissions..."
    termux-setup-storage

    echo "📥 Installing Google Drive upload tool (gupload)..."
    if [ ! -d "$HOME/google-drive-upload" ]; then
        git clone https://github.com/labbots/google-drive-upload.git $HOME/google-drive-upload
        cp $HOME/google-drive-upload/gupload $PREFIX/bin/
        chmod +x $PREFIX/bin/gupload
        echo "✅ gupload installed successfully!"
    else
        echo "✅ gupload is already installed."
    fi

    echo "⚙ Configuring rclone for Google Drive..."
    mkdir -p $HOME/.config/rclone

    # Check if rclone.conf exists and is writable
    if [ -f "$RCLONE_CONF" ]; then
        echo "🔍 Found existing rclone.conf file."
        if [ ! -w "$RCLONE_CONF" ]; then
            echo "🛠 Making rclone.conf writable..."
            chmod 600 "$RCLONE_CONF"
        fi
    else
        echo "📄 Creating new rclone.conf file..."
        touch "$RCLONE_CONF"
        chmod 600 "$RCLONE_CONF"
    fi

    # Generate rclone.conf with predefined settings (OAuth must be done manually)
    cat <<EOF > "$RCLONE_CONF"
[$RCLONE_REMOTE_NAME]
type = drive
client_id = $CLIENT_ID
client_secret = $CLIENT_SECRET
scope = drive
token = {"access_token":""}
EOF

    echo "🌐 Authenticate Google Drive manually..."
    rclone config reconnect "$RCLONE_REMOTE_NAME:"

    echo "✅ Setup complete! Testing installation..."
    echo "-------------------------------------------"
    echo "Checking installed versions:"
    rclone --version
    gupload --version
    echo "-------------------------------------------"

    echo "📌 Next steps:"
    echo "1️⃣ Authenticate Google Drive when prompted."
    echo "2️⃣ Run 'rclone lsf $RCLONE_REMOTE_NAME:' to check Drive contents."
    echo "3️⃣ Use 'gupload your_file' to upload files."
    echo "4️⃣ Use 'rclone copy /your/folder $RCLONE_REMOTE_NAME:/target_folder' to copy files."
}

# Function to upload and schedule
upload_and_schedule() {

    echo "🔍 Checking if '$FOLDER_NAME' directory exists in Google Drive..."

    # Check if the folder exists, if not, create it
    rclone lsf "$REMOTE_PARENT" | grep -q "$FOLDER_NAME/"
    if [ $? -ne 0 ]; then
        echo "📂 '$FOLDER_NAME' folder not found. Creating it..."
        rclone mkdir "$REMOTE_DIR"
        echo "✅ '$FOLDER_NAME' folder created successfully!"
    else
        echo "✅ '$FOLDER_NAME' folder already exists."
    fi

    echo "📤 Syncing .txt files from $LOCAL_DIR to $REMOTE_DIR..."

    # Sync only .txt files (upload new/modified ones, but do NOT delete anything in Drive)
    rclone copy "$LOCAL_DIR" "$REMOTE_DIR" --include "*.txt" --progress --log-file=$HOME/upload_sync_$FOLDER_NAME.log --drive-use-trash --checksum

    echo "✅ Sync completed at $(date). Check Google Drive."

    # ----------------------
    # Set up cron job to run every minute (for testing)
    # ----------------------

}

setup_cron_job() {
    echo "🕒 Setting up cron job to run every minute..."

    echo "🗑 Removing existing cron jobs..."
    crontab -r

    # Ensure Termux's cron service is installed and enabled
    manage_crond

    # Add the cron job (removes duplicates first)
    CRON_JOB="* * * * * rclone copy \"$LOCAL_DIR\" \"$REMOTE_DIR\" --include \"*.txt\" --progress --log-file=\"$LOG_FILE\" --drive-use-trash --checksum"
    crontab -l | grep -v "rclone copy" > $HOME/cron_tmp
    echo "$CRON_JOB" >> $HOME/cron_tmp
    crontab $HOME/cron_tmp
    rm $HOME/cron_tmp

    echo "✅ Cron job added! The script will run every minute."
}

monitor_system() {
    echo "📊 Monitoring system resources..."
    echo "CPU and Memory Usage:"
    top -b -n 1
    echo "Storage Usage:"
    df -h
}

# Main execution
setup_tools
refresh_rclone_token
setup_cron_job
monitor_system