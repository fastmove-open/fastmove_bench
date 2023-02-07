#!/bin/bash

echo "noopt"

echo 1 > /proc/sys/fs/copy-accel-enabled-nodes
echo 0 > /proc/sys/fs/copy-accel-local-write-threshold
echo 0 > /proc/sys/fs/copy-accel-remote-read-threshold
echo 1 > /proc/sys/fs/copy-accel-sync-wait
echo 0 > /proc/sys/fs/copy-accel-ddio-enabled
echo 0 > /proc/sys/fs/copy-accel-local-read-threshold
echo 1000 > /proc/sys/fs/copy-accel-max-dma-concurrency
echo 0 > /proc/sys/fs/copy-accel-remote-write-threshold

echo 1 > /proc/fs/copy_accel/enable
