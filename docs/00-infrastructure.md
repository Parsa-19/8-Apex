### change dns setting permanently
on all nodes:
```
$ nmcli connection modify enp0s3 ipv4.dns "8.8.8.8 8.8.4.4 1.1.1.1"
$ nmcli connection down enp0s3
$ nmcli connection up enp0s3
$ nmcli connection show enp0s3 | grep -i dns
```

---

### configure gateway on network interfaces on all nodes
on frist network interface enp0s3 configure gateway to:
```
$ nmcli conn down enp0s3
$ nmcli conn modify enp0s3 \
    ipv4.gateway 10.0.2.1 \
    ipv4.method manual
$ nmcli conn up enp0s3
```
I dont specify the gateway for second interface enp0s8 as I dont need to talk to another network through this interface and its intended to be the node's ip.

---

### assign each node a name instead of ip in /etc/hosts
on all nodes:
```
sudo tee -a /etc/hosts <<EOF
192.168.55.118  cp-1
192.168.55.119  cp-2
192.168.55.120  cp-3
192.168.55.121  node-1
192.168.55.122	node-2
192.168.55.123	app-lb
EOF
```