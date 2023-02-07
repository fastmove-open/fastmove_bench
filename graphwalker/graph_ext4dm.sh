#!/usr/bin/env bash

S16K=16384
S32K=32768
S64K=65536
S128K=131072
S256K=262144
S512K=524288

change_concurrency() {
    echo $1 > /proc/sys/fs/copy-accel-max-dma-concurrency
}

change_read_threshold() {
    echo $1 > /proc/sys/fs/copy-accel-dma-read-threshold
}

change_write_threshold() {
    echo $1 > /proc/sys/fs/copy-accel-dma-write-threshold
}

disable_ddio() {
    /home/gloit/disable-ddio
    echo 0 > /proc/sys/fs/copy-accel-ddio-enabled
}

enable_ddio() {
    /home/gloit/enable-ddio
    echo 1 > /proc/sys/fs/copy-accel-ddio-enabled
}


PMFS_DIR=/mnt/ext4
REPORT_DIR=/home/gloit/graph_results/ASPLOS23/kron30_32_ext4dm
run_graph() {
    PREFIX=$1
    mkdir -p $REPORT_DIR
    for repeat in $(seq 1 1);do
        NAME=$REPORT_DIR/$PREFIX-msppr-$repeat
        # /home/gloit/graph_results/graph_nova.bt > $NAME-stat &
        #BPF_PID=$!
        perf record -g numactl -N 0,1 -m 0,1 /home/gloit/GraphWalker-master/bin/apps/msppr \
            file /data2/kron30_32_sorted.txt \
            csrfiles $PMFS_DIR/kron30_32 \
            firstsource 0 \
            numsources 20 \
            walkspersource 2000 \
            maxwalklength 20 \
            prob 0.2 > $NAME #&
        # WORK_PID=$!
        # while ps -p $WORK_PID > /dev/null; do
        #     sleep 1
        # done
        # kill $BPF_PID
    done
}

export GRAPHCHI_ROOT=/home/gloit/GraphWalker-master

enable_ddio
for con in 0 ; do
    change_concurrency $con
    run_graph con-$con-enabled
done
