#!/bin/bash
# This script validates permissible MTU


host_name="1.1.1.1"
s=8972  # Packet size = MTU - 28
# s=1474  # for test


func_main() {  #~ begin to work
  for (( i = $s; i >= 1472; i-- )); do
    result=$( ping -c 1 -M do -s $i ${host_name} 2>&1 )
    echo "$result" | grep -q "too long"
    if (( $? == 0 )); then
      echo "Packet size = "$i", MTU = $((i + 28)) - too long"
    else
      echo "Packet size = "$i", MTU = $((i + 28)) - is good"
      break
    fi
  done
}


func_main
exit 0
