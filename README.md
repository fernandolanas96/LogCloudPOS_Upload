# LogCloudPOS_Upload
Bash script to upload files from POS to G-Drive using termux in the android device.
```bash
# Authentication Credentials
CLIENT_ID="clientId"
CLIENT_SECRET="clientsecret"

# Define Local and Remote Directories
LOCAL_DIR="/storage/emulated/0/Android/data/com.valet_manager.pointofsale/logs/"  # Local directory (modify as needed)
REMOTE_PARENT="gdrive:/Logs_Backup"  # Google Drive parent directory (auto-created, no need for manual setup)

# Customizable Folder and Remote Directory Variables
FOLDER_NAME="PPS_100"  # Modify this for each POS system

# Cron Job Configuration
CRON_JOB="* * * * * rclone copy \"$LOCAL_DIR\" \"$REMOTE_DIR\" --include \"*.txt\" --progress --log-file=\"$LOG_FILE\" --drive-use-trash --checksum"

# Note:
# - Update values as per individual POS requirements.
# - Modify the cron job timing according to the required schedule.
```
