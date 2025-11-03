#!/bin/bash
if ! docker ps | grep -q fitapp; then
    echo "$(date): Container not running, restarting..." >> ./check_container.log
    systemctl restart myapp.service
else
    echo "$(date): Container OK" >> ./check_container.log
fi
