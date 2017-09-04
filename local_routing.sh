#!/bin/bash
iptables -t mangle -I LOCAL_ROUTING 2 -p icmp -m mark --mark 0 -j MARK --set-mark 250
