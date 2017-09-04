#!/bin/bash
#LOCAL MARK 250
#ISP1 MARK 251
#ISP2 MARK 252

. network.conf

flush_routing_tables(){
#isp1
ip route flush table $routing_table1
ip rule del from $isp1_ip table $routing_table1
ip rule del fwmark 251 table $routing_table1
#isp2
ip rule del from $isp2_ip table $routing_table2
ip route flush table $routing_table2
ip rule del fwmark 252 table $routing_table2
#lookup in main table when destination is local
ip rule del prio 10 to $lan_subnet lookup main


}

add_routing_rules(){
#isp1
ip route add $isp1_network dev $isp1_interface src $isp1_ip table $routing_table1
ip route add default via $isp1_gw table $routing_table1
ip rule add from $isp1_ip table $routing_table1 prio 200
#isp2
ip route add $isp2_network dev $isp2_interface src $isp2_ip table $routing_table2
ip route add default via $isp2_gw table $routing_table2
ip rule add from $isp2_ip table $routing_table2 prio 200
#route through isp1 traffic marked with 251
ip rule add fwmark 251 table $routing_table1  prio 199
#route through isp2 traffic marked with 252
ip rule add fwmark 252 table $routing_table2  prio 199
#lookup in main table when destination is local
ip rule add prio 10 to $lan_subnet lookup main

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

add_local_routing_rules(){
ip rule add fwmark 250 table $routing_table2  prio 199
}

del_local_routing_rules(){
ip rule del fwmark 250 table $routing_table2  prio 199
}

add_local_iptables_rules(){
iptables -t mangle -N LOCAL_ROUTING
iptables -t mangle -A LOCAL_ROUTING -m conntrack ! --ctstate NEW -m connmark ! --mark 0 -j CONNMARK --restore-mark
local_user_rules
iptables -t mangle -A LOCAL_ROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark
iptables -t mangle -A OUTPUT -j LOCAL_ROUTING
}

del_local_iptables_rules(){
iptables -t mangle -D OUTPUT -j LOCAL_ROUTING
iptables -t mangle -F LOCAL_ROUTING
iptables -t mangle -X LOCAL_ROUTING
}

add_nat(){
if [ $nat_enabled -eq  1 ]
    then
        iptables -t nat -A POSTROUTING -o $isp1_interface -j MASQUERADE
        iptables -t nat -A POSTROUTING -o $isp2_interface -j MASQUERADE
fi
}

add_iptables_rules(){
iptables -t mangle -N ROUTING
iptables -t mangle -A PREROUTING -j ROUTING
iptables -t mangle -A ROUTING -m conntrack ! --ctstate NEW -m connmark ! --mark 0  -j CONNMARK --restore-mark
not_local_user_rules
iptables -t mangle -A ROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark
}

del_iptables_rules(){
if [ $nat_enabled -eq  1 ]
    then
        iptables -t nat -D POSTROUTING -o $isp1_interface -j MASQUERADE
        iptables -t nat -D POSTROUTING -o $isp2_interface -j MASQUERADE
fi
iptables -t mangle -D PREROUTING -j ROUTING
iptables -t mangle -F ROUTING
iptables -t mangle -X ROUTING
}

local_user_rules(){
./local_routing.sh
}

not_local_user_rules(){
./non_local_routing.sh
}

stop(){
if [ $local_routing -eq 1 ]
    then
       del_local_iptables_rules
       del_local_routing_rules
fi
flush_routing_tables
del_iptables_rules
disable_kernel_parameters


}

start(){
if [ $local_routing -eq 1 ]
    then
       add_local_iptables_rules
       add_local_routing_rules
fi
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
echo "="
echo "routing table $routing_table1:"
echo "="
ip r s t $routing_table1
echo "="
echo "routing table $routing_table2:"
echo "="
ip r s t $routing_table2
echo "="
ip rule ls
echo "="
echo "="
iptables -t nat -nvL POSTROUTING
echo "="
echo "="
iptables -t mangle -nvL ROUTING
echo "="
echo "="
iptables -t mangle -nvL LOCAL_ROUTING
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
