#!/bin/bash
# Stop the Kubernetes Log Export Action daemon process
echo "Stopping the Kubernetes Log Export Action daemon process..."
# Read the PID of the running kubelogs.sh script
PID=$(cat kubelogs.pid)
if [[ -z "$PID" ]]
then
  echo "kubelogs.sh is not currently running."
else
  # Kill the process
  kill -9 $PID
  echo "kubelogs.sh process (PID: $PID) has been stopped."
  # Remove the pid file
  rm kubelogs.pid
fi