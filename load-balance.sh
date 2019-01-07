#!/bin/bash

. policy-routing.conf

if [ $loadbalance -eq 1 ]
then
if [ $wan1_weight -gt $wan2_weight ]
then
ip route replace default scope global nexthop via $wan1_gateway dev $wan1_interface weight $wan1_weight \
nexthop via $wan2_gateway dev $wan2_interface weight $wan2_weight
else
ip route replace default scope global nexthop via $wan2_gateway dev $wan2_interface weight $wan2_weight \
nexthop via $wan1_gateway dev $wan1_interface weight $wan1_weight
fi
fi
