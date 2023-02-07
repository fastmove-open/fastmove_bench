#!/bin/bash

set -e
# set -x

# Import numa related functions
source misc/fn_numa

# Import fs related functions
source misc/fn_fs

# Import other misc functions
source misc/fn_misc

export MOUNT_DIR=/mnt/pmem

export PATH=/usr/local/bin:$PATH

######################################################################
#
# To add a benchmark, declare a fn_${BENCH_NAME} in a folder
#  named ${BENCH_NAME}, and define the following hooks:
#
# 1. setup_single_bench:
#    - Setup profiling/other things before benchmark
#    - Arguments: $1: The output filename
#                 $2: 0 for single socket, 1 for dual socket
#
# 2. bench_single_main:
#    - Run the actual benchmark seq
#    - Arguments: $1: The output filename
#                 $2: 0 for single socket, 1 for dual socket
#
# 3. stop_single_bench:
#    - Stop profiling/other cleanups after benchmark
#    - Arguments: $1: The output filename
#                 $2: 0 for single socket, 1 for dual socket
#
# 4. init_single_bench:
#    - A run-once function that is run only once before everything begins
#    - No arguments
#
# Available global variables:
#
# 1. BENCH_DIR: Current benchmark dir
# 2. MOUNT_DIR: PMEM mount dir
#
######################################################################

# setting_bench="graphwalker mysql"
# setting_fs="xfs ext4 nova"
# setting_skt_setup="SS DS"
# setting_method_setup="DMA CPU"
# setting_write_thresh="16384"
# setting_read_thresh="65536"
# setting_remote_write_thresh="16384"
# setting_remote_read_thresh="16384"
# setting_watermark="20"
# setting_chunk="2"
# setting_main_wr="0"
# setting_worker_wr="1"
# setting_scatter="1"

# If you have a already defined bench profile in profile directory
# put it here

# setting_bench_profile="breakdown_t0_cpu breakdown_t4_scatter breakdown_t5_threshold_read breakdown_t7_bulkreadsplit"
# setting_bench_profile="breakdown_t7_bulkreadsplit"
# setting_bench_profile="mysql_ss"
# setting_bench_profile="graphwalker_ss"
# setting_bench_profile="filebench_ss"
# setting_bench_profile="filebench_bench"
# setting_bench_profile="breakdown_t5_threshold_read  breakdown_t6_bulkreadsplit"
# setting_bench_profile="breakdown_t0_cpu breakdown_t7_threshold_write"
# setting_bench_profile="breakdown_t3_concurrency"
# setting_bench_profile="breakdown_t6_threshold_read breakdown_t7_threshold_write"
# setting_bench_profile="breakdown_t2_scatter breakdown_t4_bulkreadsplit breakdown_t6_threshold_write"

source ./bench_filebench_breakdown_r

#
# Main benchmark function
# We assume that everything is done before the benchmark begin
# Everything before the benchmark should be done before this function is called
#
# Related hooks
#  - setup_single_bench output_file_name socket_num
#  - bench_single_main output_file_name socket_num
#  - stop_single_bench output_file_name socket_num
#
# Argument list:
#  - $1 for benchmark file name
#  - $2 for configuration: 0 for single socket, 1 for dual socket
#
function bench_main {
    # General setup
    # Setup numactl cmd
    if [[ "x$2" == "x1" ]]; then
        numactl_cmd="numactl --interleave=all "
    else
        numactl_cmd="numactl -N 0 -m 0 "
    fi

    # Drop caches

    # Bench specific setup
    if [[ $(type -t setup_single_bench) = function ]]; then
        setup_single_bench $1 $2
    fi

    echo 3 >/proc/sys/vm/drop_caches

    # echo 0 >/proc/fs/fastmove/stats
    # echo 0 > /proc/fs/NOVA/$dev_name/timing_stats
    # cat /proc/`pidof msppr`/stat > $1_proc_mysql_before
    bench_single_main $1 $2
    # cat /proc/fs/fastmove/stats >$1_fm_stats
    # cat /proc/fs/NOVA/$dev_name/timing_stats > $1_nova_stats
    # cat /proc/`pidof msppr`/stat > $1_proc_mysql_after

    if [[ $(type -t stop_single_bench) = function ]]; then
        stop_single_bench $1 $2
    fi
}

# Prepare a benchmark
# This function is called BEFORE every benchmark_main so as to prepare the benchmark
#  environment
# When we reach this function, we assume that only NUMA 0 is enabled
# Argument list:
#  - $1 = 0 for single socket, 1 for striped target, the stripe is always /dev/pmem0 + /dev/pmem1
#  - $2 = 0 for CPU, 1 for DMA
#  - $3: reserved (not needed)
#  - $4: Filesystem to use
#  - $5: accel: local-write: Local write threshold
#  - $6: accel: local-read: Local read threshold
#  - $7: accel: chunks: Number of chunks to split (if is to split)
#  - $8: accel: watermark: Decide whether to split based on inflight and this
#  - $9: accel: main-switch: Routine to be used on master thread: 0 for DMA, 1 for CPU
#  - $10: accel: worker-switch: Routine to be used on worker thread, 0 for DMA, 1 for CPU
#  - $11: accel: scatter: Whether we want to use the new scatter routine?
#  - $12: accel: user-nums: Concurrency control
#  - $13: accel: remote-read
#  - $14: accel: remote-write
function prepare_benchmark {
    # Prepare a stripe target (or non-stripe target)
    echo "==> Check target"
    if [ $1 -eq 1 ]; then
        dev_target="/dev/mapper/stripe_dev"
        dev_name="dm-0"
        perl /home/chenlf/create_dm.pl /dev/pmem0 /dev/pmem1
    else
        dev_target="/dev/pmem0"
        dev_name="pmem0"
    fi
    echo "<== Target is $dev_target"

    # Prepare Hybrid Engine
    echo "==> Setting HE"
    sysctl accel.fastmove=0
    if [ $2 -eq 0 ]; then
        echo "<== Setting for CPU"
        sysctl accel.mode=0
        bin/enable-ddio >/dev/null 2>&1
    else
        echo "<== Setting for DMA"
        sysctl accel.mode=1
        if [ $1 -eq 1 ]; then
            if [ $4 == "nova" ]; then
                sysctl accel.mode=1
            else
                sysctl accel.mode=2
            fi
        fi

        # sysctl accel.watermark=$8
        sysctl accel.dbg-mask=0x11
        sysctl accel.ddio=1
        sysctl accel.sync-wait=1
        sysctl accel.local-read=$6
        sysctl accel.local-write=$5
        # sysctl accel.main-switch=$9
        # sysctl accel.worker-switch=${10}
        # bin/disable-ddio >/dev/null 2>&1
        sysctl accel.chunks=$7
        sysctl accel.user-nums=${12}
        sysctl accel.scatter=0
        sysctl accel.remote-read=${13}
        sysctl accel.remote-write=${14}
    fi
    if [ $1 -eq 0 ]; then
        echo "<== Setting for non-stripe target"
        sysctl accel.num-nodes=1
        disable_numa 1
    else
        echo "<== Setting for striped target"
        sysctl accel.num-nodes=2
    fi
    sysctl accel.fastmove=1

    # Mount Filesystem, umount before mount
    echo "==> Mount"
    mountret=$(mount | grep -i pmem | wc -l)
    if [ $mountret -ne 0 ]; then
        umount $MOUNT_DIR
    fi
    if [ $4 == "nova" ]; then
        format_nova $1 $dev_target "$MOUNT_DIR"
        mount_nova $1 $dev_target "$MOUNT_DIR"
    elif [ $4 == "ext4" ]; then
        format_ext4 $1 $dev_target "$MOUNT_DIR"
        mount_ext4 $1 $dev_target "$MOUNT_DIR"
    elif [ $4 == "xfs" ]; then
        format_xfs $1 $dev_target "$MOUNT_DIR"
        mount_xfs $1 $dev_target "$MOUNT_DIR"
    elif [ $4 == "odinfs" ]; then
        format_odinfs $1 $dev_target "$MOUNT_DIR"
        mount_odinfs $1 $dev_target "$MOUNT_DIR"
    else
        echo "ERROR: Not a valid filesystem $4"
        exit 1
    fi
}

# Final benchmark cleanup
function end_benchmark {
    # Umount PMEM
    sleep 5
    umount $MOUNT_DIR

    # Destroy stripped target if exists
    if [ -e "/dev/mapper/stripe_dev" ]; then
        dmsetup remove /dev/mapper/stripe_dev
    fi

    if [ $1 == "odinfs" ]; then
        if [ $2 -eq 0 ]; then
            parradm delete /dev/pmem0
        else
            parradm delete /dev/pmem0 /dev/pmem1
        fi
    fi

    disable_numa 1
}

# Initialize the benchmark
# This function is called BEFORE the whole benchmark starts
#
# Arguments:
#  - $1: Benchmark list
function init_all {
    # Disable SMT
    echo "off" | sudo tee /sys/devices/system/cpu/smt/control

    # Enable only 2 NUMA nodes
    disable_numa 1
    disable_numa 2
    disable_numa 3

    # Disable DDIO
    # bin/disable-ddio

    if [ -e "/dev/mapper/stripe_dev" ]; then
        dmsetup remove /dev/mapper/stripe_dev
    fi

    mkdir -p /run/mysqld
    chown -R mysql:mysql /run/mysqld

    for bench in $1; do
        export BENCH_DIR=${LOCAL_DIR}/${bench}
        source ${bench}/fn_${bench}
        if [[ $(type -t init_single_bench) = function ]]; then
            init_single_bench
        fi
    done

    sysctl accel.dbg-mask=0x11
    sysctl accel.show-stats=1
}

# Setup result directory
date_prefix=$(date --iso-8601=seconds)
for profile in "${setting_bench_profile[@]}"; do
    source profile/$profile

    dir_name="result_$date_prefix/$profile"
    mkdir -p $dir_name

    export LOCAL_DIR=$(pwd)

    init_all $setting_bench

    for bench in $setting_bench; do
        export BENCH_DIR=${LOCAL_DIR}/${bench}
        source ${bench}/fn_${bench}
        mkdir -p $dir_name/$bench
        for chunks in $setting_chunk; do
            for watermark in $setting_watermark; do
                for lwrite_thrsh in $setting_write_thresh; do
                    for lread_thrsh in $setting_read_thresh; do
                        for fs in $setting_fs; do
                            for ssetup in $setting_skt_setup; do
                                for msetup in $setting_method_setup; do
                                    for main_wr in $setting_main_wr; do
                                        for worker_wr in $setting_worker_wr; do
                                            for i in 16; do
                                                for user_num in $setting_user_nums; do
                                                    for sct in $setting_scatter; do
                                                        for rread_thrsh in $setting_remote_read_thresh; do
                                                            for rwrite_thrsh in $setting_remote_write_thresh; do
                                                                if [[ $ssetup == "DS" ]]; then
                                                                    s_cmd=1
                                                                else
                                                                    s_cmd=0
                                                                fi

                                                                if [[ $msetup == "CPU" ]]; then
                                                                    m_cmd=0
                                                                else
                                                                    m_cmd=1
                                                                fi

                                                                echo "==> Benchmark begin for $bench: $ssetup-$msetup-$i-$fs-$lwrite_thrsh-$lread_thrsh-$chunks-$watermark-$sct"
                                                                prepare_benchmark $s_cmd $m_cmd $i $fs $lwrite_thrsh $lread_thrsh $chunks $watermark $main_wr $worker_wr $sct $user_num $rread_thrsh $rwrite_thrsh
                                                                bench_main "$dir_name/$bench/$ssetup-$msetup-$i-$fs-$lwrite_thrsh-$lread_thrsh-$chunks-$watermark-$main_wr-$worker_wr-$sct" $s_cmd
                                                                end_benchmark $fs $s_cmd
                                                            done
                                                        done
                                                    done
                                                done
                                            done
                                        done
                                    done
                                done
                            done
                        done
                    done
                done
            done
        done
        unset bench_single_main
        unset stop_single_bench
        unset setup_single_bench
    done
done

rm -rf latest
ln -s "result_$date_prefix" latest

