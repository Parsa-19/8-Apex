### change dns setting permanently
on all nodes:
```
$ nmcli connection modify enp0s3 ipv4.dns "8.8.8.8 8.8.4.4 1.1.1.1"
$ nmcli connection down enp0s3
$ nmcli connection up enp0s3
$ nmcli connection show enp0s3 | grep -i dns
```

---

### assign each node a name instead of ip in /etc/hosts
on all nodes:
```
sudo tee -a /etc/hosts <<EOF
192.168.16.118  cp-1
192.168.16.119  cp-2
192.168.16.120  cp-3
192.168.16.121  node-1
192.168.16.122	node-2
192.168.16.123	lb-1
192.168.16.124	lb-2
EOF
```