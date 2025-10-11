#!/bin/sh

echo "Syncing backups to remote repository..."
rclone sync ./backups remote:/mc-backups
