# Policy-Routing

bash script to handle policy routing

# SCENARIO

This is a common scenario where you can use this script

```
                                                                
                                          +------------+       |                                          
                                          |            |       |
                            +-------------+    ISP 1   +-------|
                            |             |            |       |
                     +------+-------+     +------------+       |
                     |     eth0     |                          |
                     |              |                          |
 Local network ------+    Router    |                          | INTERNET 
                     |              |                          |
                     |     eth2     |                          |
                     +------+-------+     +------------+       |
                            |             |            |       |
                            +-------------+    ISP 2   +-------|
                                          |            |       |
                                          +------------+       | 
```

# REQUIREMENTS

- iproute2
- iptables

# INSTRUCTIONS

add two (if you have two ISP connections) routing tables in /etc/iproute2/rt_tables.
In this example i added table 251 and 252

```
#
# reserved values
#
255	local
254	main
253	default
252     wan2
251     wan1
0	unspec
#
# local
#
#1	inr.ruhep
```

Edit the `policy-routing.conf` file and change the parameters in the first section accordingly to your configuration
Specify the traffic that you want to route in the routing_rules.cfg file.
For example,if you want to route all HTTP traffic coming from 192.168.122.0/24 network through the second ISP add:

```
[rule1]
src-ip =
src-net = 192.168.122.0/24
src-interface =
protocol = tcp
dst-port = 80
dst-ip = 
dst-net =
gw = wan2
routing_type = routing
```

Note that the routing rules has to be added with the above exact syntax,you always have to specify in the first line `[ruleN]` where N is an incremental integer

# USAGE

You need only to run the script from a root terminal in this way

`./policy-routing.sh start`

To have some informations about run

`./policy-routing.sh status`

# CREDITS

took the inspiration from here:

https://www.tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.rpdb.multiple-links.html
