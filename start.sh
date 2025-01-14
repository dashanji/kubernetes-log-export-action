#!/bin/bash

# Print the values of the arguments
echo "namespaces: $1"
echo "output_dir: $2"
echo "resources: $3"
echo "show_timestamps: $4"

# Start the Kubernetes Log Export Action daemon process
echo "Starting the Kubernetes Log Export Action daemon process..."
echo "To stop the daemon process, run ./stop.sh"

echo "Running kubelogs.sh on namespaces: $1, and outputting to $2."
while true
do
    bash kubelogs.sh -n $1 -o $2 -r $3 --timestamps $4
    sleep 1
done