#!/bin/bash

# Start the Kubernetes Log Export Action daemon process
echo "Starting the Kubernetes Log Export Action daemon process..."
echo "To stop the daemon process, run ./stop.sh"

echo "Running kubelogs.sh on namespaces: $NAMESPACES, and outputting to $OUTPUT_DIR."
bash kubelogs.sh -n "$NAMESPACES" -o $OUTPUT_DIR --timestamps $SHOW_TIMESTAMPS &
echo $! > kubelogs.pid