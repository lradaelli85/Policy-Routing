# Policy-Routing
-REQUIREMENTS

iproute2
iptables

-INSTRUCTIONS

add two (if you have two ISP connections) routing tables in /etc/iproute2/rt_tables
i.e

251     isp1
252     isp2

Edit the network.conf file change parameters in the first section accordingly to your configuration
Add the iptables rules to mark the desired traffic in the below flush_routing_tables

-local_routing.sh
This file should be used only to route locally generated traffic.

-non_local_routing.sh
This file should be used only to route non locally generated traffic (i.e if the linux box act as a router and you want to redirect traffic from hosts
that are using it as gateway).

Use mark 250 for locally generated traffic,mark 252 for traffic routed through ISP2,and mark 251 for traffic routed through ISP1


#USAGE

you'll find a bash script ,that will do what i mentioned above.
All parameters are read from a configuration file called network.conf.
You need only to run the script from a root terminal in this way

./do_routing.sh start
