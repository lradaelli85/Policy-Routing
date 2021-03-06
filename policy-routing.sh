#!/bin/bash

. policy-routing.conf

flush_routing_tables(){
#wan1
ip route flush table $wan1_routing_table
ip rule del from $wan1_ip_address table $wan1_routing_table
ip rule del fwmark $wan1_mark table $wan1_routing_table

#wan2
ip rule del from $wan2_ip_address table $wan2_routing_table
ip route flush table $wan2_routing_table
ip rule del fwmark $wan2_mark table $wan2_routing_table

#lookup in main table when destination is local
#ip rule del to $lan_subnet lookup main

if [ $loadbalance -eq 0 ]
  then
    ip route replace default scope global nexthop via $wan1_gateway dev $wan1_interface
fi
}

add_routing_rules(){
#wan1
ip route add $wan1_network_address dev $wan1_interface src $wan1_ip_address table $wan1_routing_table
ip route add default via $wan1_gateway table $wan1_routing_table
ip rule add from $wan1_ip_address table $wan1_routing_table prio 199

#wan2
ip route add $wan2_network_address dev $wan2_interface src $wan2_ip_address table $wan2_routing_table
ip route add default via $wan2_gateway table $wan2_routing_table
ip rule add from $wan2_ip_address table $wan2_routing_table prio 200

#route through wan1 traffic marked with 1
ip rule add fwmark $wan1_mark table $wan1_routing_table prio 199

#route through wan2 traffic marked with 2
ip rule add fwmark $wan2_mark table $wan2_routing_table prio 200

#lookup in main table when destination is local
#ip rule add to $lan_subnet lookup main prio 10

if [ $loadbalance -eq 1 ]
 then
   ./load-balance.sh
fi
  
}

disable_kernel_parameters(){

#disable forwarding
if [ $forwarding_enabled -eq 1 ]
  then
    sysctl -w net.ipv4.ip_forward=0
fi

#enable reverse path filter
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
}

enable_kernel_parameters(){

#enable forwarding
if [ $forwarding_enabled -eq 1 ]
  then
    sysctl -w net.ipv4.ip_forward=1
fi
#disable reverse path filter
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
}


add_local_iptables_rules(){
if [ $local_routing -eq 1 ]
  then
    iptables -t mangle -N LOCAL_ROUTING
    user_rules LOCAL_ROUTING
    iptables -t mangle -A OUTPUT -j LOCAL_ROUTING
fi
}

del_local_iptables_rules(){
if [ $local_routing -eq 1 ]
  then
    iptables -t mangle -D OUTPUT -j LOCAL_ROUTING
    iptables -t mangle -F LOCAL_ROUTING
    iptables -t mangle -X LOCAL_ROUTING
fi
}

add_nat(){
if [ $nat_enabled -eq  1 ]
  then
    iptables -t nat -A POSTROUTING -o $wan1_interface -j MASQUERADE
    iptables -t nat -A POSTROUTING -o $wan2_interface -j MASQUERADE
fi
}

add_iptables_rules(){
iptables -t mangle -N ROUTING
#iptables -t mangle -A ROUTING  -m mark ! --mark 0 -j RETURN
iptables -t mangle -A PREROUTING -m conntrack ! --ctstate NEW -m connmark ! --mark 0  -j CONNMARK --restore-mark
iptables -t mangle -A PREROUTING -j ROUTING
user_rules ROUTING
iptables -t mangle -A POSTROUTING -m conntrack --ctstate NEW -m mark --mark 0 -o $wan1_interface -j CONNMARK --set-mark $wan1_mark
iptables -t mangle -A POSTROUTING -m conntrack --ctstate NEW -m mark --mark 0 -o $wan2_interface -j CONNMARK --set-mark $wan2_mark
iptables -t mangle -A POSTROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -o $wan1_interface -j CONNMARK --save-mark
iptables -t mangle -A POSTROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -o $wan2_interface -j CONNMARK --save-mark
}

del_iptables_rules(){
if [ $nat_enabled -eq  1 ]
  then
    iptables -t nat -D POSTROUTING -o $wan1_interface -j MASQUERADE
    iptables -t nat -D POSTROUTING -o $wan2_interface -j MASQUERADE
fi
iptables -t mangle -D PREROUTING -m conntrack ! --ctstate NEW -m connmark ! --mark 0  -j CONNMARK --restore-mark
iptables -t mangle -D PREROUTING -j ROUTING
iptables -t mangle -F ROUTING
iptables -t mangle -X ROUTING
iptables -t mangle -D POSTROUTING -m conntrack --ctstate NEW -m mark --mark 0 -o $wan1_interface -j CONNMARK --set-mark $wan1_mark
iptables -t mangle -D POSTROUTING -m conntrack --ctstate NEW -m mark --mark 0 -o $wan2_interface -j CONNMARK --set-mark $wan2_mark
iptables -t mangle -D POSTROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -o $wan1_interface -j CONNMARK --save-mark
iptables -t mangle -D POSTROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -o $wan2_interface -j CONNMARK --save-mark

}

user_rules(){
./routing_rule.py $1
}

stop(){
del_local_iptables_rules
flush_routing_tables
del_iptables_rules
disable_kernel_parameters
}

start(){
add_local_iptables_rules
add_nat
enable_kernel_parameters
add_iptables_rules
add_routing_rules
}

Who_Am_I(){
if [ `id -u` -ne 0 ]
  then
    echo "need root privileges"
    exit 1;
fi
}

status(){
clear
echo " "
echo "routing table $wan1_routing_table:"
echo "==================================="
ip r s t $wan1_routing_table
echo " "
echo " "
echo "routing table $wan2_routing_table:"
echo "==================================="
ip r s t $wan2_routing_table
echo " "
echo " "
echo "ip rule rules"
echo "==================================="
ip rule ls
echo " "
echo " "
echo "iptables mark rules"
echo "==================================="
iptables -t mangle -vL ROUTING
if [ $local_routing -eq 1 ]
  then
    echo " "
    iptables -t mangle -nvL LOCAL_ROUTING
fi
echo " "
echo " "
echo "main routing table"
echo "===================================="
ip route ls
}

case $1 in
start)   Who_Am_I
         start
         ;;

restart) Who_Am_I
         stop
         start
         ;;
stop)    Who_Am_I
         stop
         ;;
status)  Who_Am_I
         status
         ;;

*)       echo "usage $0 [stop|start|restart|status]"
         ;;
esac
