#!/bin/bash

set -e

is_ipv4_forwarding_on="$ip_on_by_def"

if [[ "$is_ipv4_forwarding_on" == "1" ]]; then
  echo "IP forwarding was on by default 👀so keep it as it is"
else
  # manipulate the kernel variables
  echo "Disabling IP forwarding..."
  sudo sysctl -w net.ipv4.ip_forward=0
fi

echo "Deleting namespaces..."
ip netns del ns1 || true
ip netns del ns2 || true
ip netns del router-ns || true

echo "Cleanup complete."
