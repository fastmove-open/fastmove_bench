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
REPORT_DIR=/home/gloit/graph_results/kron30_32_ext4
run_graph() {
    PREFIX=$1
    mkdir -p $REPORT_DIR
    for repeat in $(seq 2 2);do
        NAME=$REPORT_DIR/$PREFIX-msppr-$repeat
        /home/gloit/graph_results/graph_iter.bt > $NAME-stat &
        BPF_PID=$!
        numactl -N 0 -m 0 /home/gloit/GraphWalker-master/bin/apps/msppr \
            file /data2/kron30_32_sorted.txt \
            csrfiles $PMFS_DIR/kron30_32 \
            firstsource 0 \
            numsources 20 \
            walkspersource 2000 \
            maxwalklength 20 \
            prob 0.2 > $NAME &
        WORK_PID=$!
        while ps -p $WORK_PID > /dev/null; do
            sleep 1
        done
        kill $BPF_PID

        NAME=$REPORT_DIR/$PREFIX-graphlet-$repeat
        /home/gloit/graph_results/graph_iter.bt > $NAME-stat &
        BPF_PID=$!
        numactl -N 0 -m 0 /home/gloit/GraphWalker-master/bin/apps/graphlet \
            file /data2/kron30_32_sorted.txt \
            csrfiles $PMFS_DIR/kron30_32 \
            N 1073741824 \
            R 100000 \
            L 4 \
            prob 0.2 > $NAME &
        WORK_PID=$!
        while ps -p $WORK_PID > /dev/null; do
            sleep 1
        done
        kill $BPF_PID

        NAME=$REPORT_DIR/$PREFIX-simrank-$repeat
        /home/gloit/graph_results/graph_iter.bt > $NAME-stat &
        BPF_PID=$!
        numactl -N 0 -m 0 /home/gloit/GraphWalker-master/bin/apps/simrank \
            file /data2/kron30_32_sorted.txt \
            csrfiles $PMFS_DIR/kron30_32 \
            a 1 \
            b 2 \
            R 1400 \
            L 11 \
            prob 0.2 > $NAME &
        WORK_PID=$!
        while ps -p $WORK_PID > /dev/null; do
            sleep 1
        done
        kill $BPF_PID

        # numactl -N 0 -m 0 /home/gloit/GraphWalker-master/bin/apps/rwdomination \
        #     file /data2/kron30_32_sorted.txt \
        #     csrfiles /mnt/NOVA/kron30_32 \
        #     N 1073741824 \
        #     R 1 \
        #     L 5 \
        #     prob 0.2 > $REPORT_DIR/$PREFIX-graphlet-$repeat
    done
}

export GRAPHCHI_ROOT=/home/gloit/GraphWalker-master

enable_ddio
for con in 0 4; do
    change_concurrency $con
    run_graph con-$con-enabled
done
