#!/bin/bash

set -e

is_ipv4_forwarding_on=$(cat /proc/sys/net/ipv4/ip_forward)

if [[ "$is_ipv4_forwarding_on" == "1" ]]; then
  echo "IP forwarding is on by default 👀"
  export ip_on_by_def=1
else
  # manipulate the kernel variables
  echo "Enabling IP forwarding..."
  export ip_on_by_def=0
  sudo sysctl -w net.ipv4.ip_forward=1
fi

# creating new network namespaces
echo "Creating network namespaces"

ip netns add ns1
ip netns add ns2
ip netns add router-ns

# configuring the network namespaces
echo "Configuring network namespace 1"

# piping, one end being veth-ns1 and another being veth-r1.
# Packets sent to veth-ns1 come out of veth-r1, and vice versa.
ip link add veth-ns1 type veth peer name veth-r1

# moving the virtual network interface veth-ns1 into the network namespace ns1.
ip link set veth-ns1 netns ns1

# same but now another end to router-ns
ip link set veth-r1 netns router-ns

echo "ns1 --- [veth-ns1] <====> [veth-r1] --- router-ns"

# repeat, but for ns2
echo "Configuring network namespace 2"
ip link add veth-ns2 type veth peer name veth-r2
ip link set veth-ns2 netns ns2
ip link set veth-r2 netns router-ns

echo "Assigning ips"

# Executing the commands in ns1
ip netns exec ns1 ip addr add 10.0.1.10/24 dev veth-ns1 # Assigning IP to veth-ns1 interface
ip netns exec ns1 ip link set veth-ns1 up               # Enabling
ip netns exec ns1 ip link set lo up                     # enabling loopback
ip netns exec ns1 ip route add default via 10.0.1.1     # Add default ip gateway to 10.0.1.1, Note here we have IPs ranging from 10.0.1.1 - 10.0.1.255

ip netns exec ns2 ip addr add 10.0.2.10/24 dev veth-ns2
ip netns exec ns2 ip link set veth-ns2 up
ip netns exec ns2 ip link set lo up
ip netns exec ns2 ip route add default via 10.0.2.1 # By default forward to 10.0.2.1

echo "Configuring router"
ip netns exec router-ns ip addr add 10.0.1.1/24 dev veth-r1 # router and host both on same subnet
ip netns exec router-ns ip addr add 10.0.2.1/24 dev veth-r2
ip netns exec router-ns ip link set veth-r1 up
ip netns exec router-ns ip link set veth-r2 up
ip netns exec router-ns ip link set lo up
ip netns exec router-ns sysctl -w net.ipv4.ip_forward=1 # enable forwarding between interfaces

echo "ns1 --- [veth-ns1 10.0.1.10] <====> [veth-r1 10.0.1.1 | router-ns | veth-r2 10.0.2.1] <====> [veth-ns2 10.0.2.10] --- ns2"

echo "Ip address configuration of ns1"
ip netns exec ns1 ip address show

echo "Ip address configuration of ns2"
ip netns exec ns2 ip address show

echo "ip address configuration of router-ns"
ip netns exec router-ns ip address show

echo "-----------------------------------------"

echo "routing table of ns1"
ip netns exec ns1 ip route show

echo "routing table of ns2"
ip netns exec ns2 ip route show

echo "routing table of router-ns"
ip netns exec router-ns ip route show

echo "-----------------------------------------"

echo "sending a ping from ns1 to ns2"
ip netns exec ns1 ping 10.0.2.10
