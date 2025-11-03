#!/bin/bash

echo "=== $(date) ===" >> ./sysinfo.log
uptime >> ./sysinfo.log
df -h >> ./sysinfo.log
echo "---------------------------" >> ./sysinfo.log
