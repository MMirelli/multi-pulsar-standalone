#!/bin/bash
echo "Stopping all standalone clusters"
for pid in $(ps -eaf | grep ".*java.*standalone.conf.*" | awk '{print $2}'); do
    kill -9 $pid
done
sleep 5
echo "Check that no standalone kwown port is still listening"
netstat -ant | grep LISTEN
