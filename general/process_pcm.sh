#!/bin/bash

# This file is to print a svg file based on the pcm-memory output trace
# Since different commands are required to extract different numbers from
# trace, one will need to manually fill in the commands

if [ -z $1 ]; then
  echo "Usage: $0 pcm_trace_file"
  exit 1
fi

# Graph title
Graph_Title="NODE 3 Memory"

# Commands to get different types of numbers
# Please use scheme like
#   "${Legend to be shown in graph}:${Command to get the number}"
declare -A cmds
cmds=(
  ["Memory Node Bandwidth"]="$(cat $1 | grep -i 'NODE 3 Memory' | cut -d '-' -f 7 | tr -s ' ' | cut -d ' ' -f 6)"
  ["PMM Read"]="$(cat $1 | grep -i 'NODE 0 PMM Read' | cut -d '-' -f 3 | tr -s ' ' | cut -d ' ' -f 7)"
  ["PMM Write"]="$(cat $1 | grep -i 'NODE 0 PMM Write' | cut -d '-' -f 3 | tr -s ' ' | cut -d ' ' -f 6)"
)

# GNU Plot common cmd
gnuplt_comm_cmd="
  set yrange [0:15000]
  set terminal svg enhanced background rgb 'white'
  set key outside center bottom maxrows 2
  set title \"$Graph_Title\"
  set output \"$1.svg\"
"

node3_mem_bw=$(cat $1 | grep -i 'NODE 3 Memory' | cut -d '-' -f 7 | tr -s ' ' | cut -d ' ' -f 6 )
node0_pmem_rbw=$(cat $1 | grep -i 'NODE 0 PMM Read' | cut -d '-' -f 3 | tr -s ' ' | cut -d ' ' -f 7)
node0_pmem_wbw=$(cat $1 | grep -i 'NODE 0 PMM Write' | cut -d '-' -f 3 | tr -s ' ' | cut -d ' ' -f 6)

# Begin process each commands
filename=()
for k in "${!cmds[@]}"; do
  v=${cmds[$k]}

  # Generate tmp file for this
  rand_filename="$(echo $RANDOM | md5sum | head -c 5; echo;)_$k.tmp"
  filename+=("$rand_filename")

  # Push data here
  begin=0
  for i in $v; do
    echo $begin ' ' $i >> "$rand_filename"
    begin=$(($begin+1))
  done

  # Append plot line to gnuplot cmd
  gnuplt_pltcmd+="\"$rand_filename\" with lines title \"$k\","
done

gnuplot <<-EOF
  $gnuplt_comm_cmd
  plot $gnuplt_pltcmd
EOF

for fname in "${filename[@]}"; do
  rm -rf "$fname"
done
