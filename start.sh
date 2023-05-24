#!/bin/bash

# Start the Kubernetes Log Export Action daemon process
echo "Starting the Kubernetes Log Export Action daemon process..."
echo "To stop the daemon process, run ./stop.sh"

while true
do
    # 判断环境变量是否设置，如果设置则启动守护进程
    if [ "$MY_DAEMON" = "true" ]; then
        # 启动守护进程
        bash kubelogs.sh -n $NAMESPACES -o $OUTPUT_DIR --timestamps $SHOW_TIMESTAMPS
        echo "Daemon started."
    fi

    # 等待一段时间后，检查环境变量是否被修改，如果被修改则停止守护进程
    sleep 1

    if [ "$MY_DAEMON" = "false" ]; then
        # 停止守护进程
        killall my_daemon
        echo "Daemon stopped."
    fi
    #echo "Running kubelogs.sh on namespaces: $NAMESPACES, and outputting to $OUTPUT_DIR."
    
    #sleep 1
done