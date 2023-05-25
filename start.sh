#!/bin/bash

# Print the values of the arguments
echo "namespaces: $1"
echo "arg2: $2"
echo "arg3: $3"

# Start the Kubernetes Log Export Action daemon process
echo "Starting the Kubernetes Log Export Action daemon process..."
echo "To stop the daemon process, run ./stop.sh"

echo "Running kubelogs.sh on namespaces: $NAMESPACES, and outputting to $OUTPUT_DIR."
while true
do
    bash kubelogs.sh -n $1 -o $2 --timestamps $3
    sleep 1
done