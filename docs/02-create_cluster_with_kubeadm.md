### prerequisites on each node:
* 2 GB or more of RAM
* 2 CPUs or more
* Unique hostname, MAC address, and product_uuid for every node
 
---

### verify MAC address and product_uuid

k8s use these values to identify each node in cluster.

1. check MAC address:
```
$ ip link
or
$ ip a
or
$ ifconfig -a
```
2. check product_uuid:
```
$ sudo cat /sys/class/dmi/id/product_uuid 
```

each value has to be unique.

---

### turn off swap on each node

remove swap partition and add its storage to lv root:
```
$ sudo swapoff -a                     # disable swap
$ sudo swapoff /dev/rlm_vbox/swap     # disable swap
$ free -h         # verify
$ swapon --show   # verify
$ nano /etc/fstab # remove swap line
$ sudo systemctl daemon-reload
$ sudo findmnt --verify
$ sudo lvremove /dev/rlm_vbox/swap
$ sudo lvextend -l +100%FREE /dev/rlm_vbox/root
$ sudo xfs_growfs /
$ df -h
$ lsblk
$ vgs
```

remove swap refrences from grub:
```
$ nano /etc/default/grub 
```

replace this line:
```
GRUB_CMDLINE_LINUX="crashkernel=2G-64G:256M,64G-:512M resume=UUID=71a46390-5a1f-45a7-b15d-8815feece9e3 rd.lvm.lv=rlm_vbox/root rd.lvm.lv=rlm_vbox/swap"
```

with this line:
```
GRUB_CMDLINE_LINUX="crashkernel=2G-64G:256M,64G-:512M rd.lvm.lv=rlm_vbox/root"
```

recreate grub and initramfs:
``` 
$ sudo grub2-mkconfig -o /boot/grub2/grub.cfg --update-bls-cmdline     # rebuild grub config
$ sudo dracut --regenerate-all --force     # rebuild the initramfs
```

check grub parameters for swap refrences. you shouldnt see any swap refrence.
```
$ sudo grubby --info=ALL | grep -E 'kernel=|args='
```

if you still have those swap refrences remove those parameters from all kernels with with grubby (replace the UUID with your own swap UUID):
```
$ sudo grubby --update-kernel=ALL \
  --remove-args="resume=UUID=71a46390-5a1f-45a7-b15d-8815feece9e3 rd.lvm.lv=rlm_vbox/swap"
```
the check it again with the `grubby --info=ALL` command. they have to be gone by now.

---

### configure ansible to run playbooks

we manage and run ansible playbooks form `CP-1`.
```
$ mkdir ansible-plays
```

create a `inventory.ini` file and add this in it:
```
[control-planes]
cp-1              ansible_host=192.168.16.118     ansible_connection=ssh      ansible_user=parsa
cp-2              ansible_host=192.168.16.119     ansible_connection=ssh      ansible_user=parsa
cp-3              ansible_host=192.168.16.120     ansible_connection=ssh      ansible_user=parsa

[workers]
node-1            ansible_host=192.168.16.121     ansible_connection=ssh      ansible_user=parsa
node-2            ansible_host=192.168.16.122     ansible_connection=ssh      ansible_user=parsa

[lb]
lb-1            ansible_host=192.168.16.123     ansible_connection=ssh      ansible_user=parsa
lb-2            ansible_host=192.168.16.124     ansible_connection=ssh      ansible_user=parsa 
```

first install required ansible collections:
```
$ ansible-galaxy collection install community.general
$ ansible-galaxy collection install ansible.posix
``` 

create another file named `k8s-dependencies.yml` to install and configure all dependencies:
this file is located in the same dir in this folder [here](k8s-dependencies.yml).

run the playbook:
```
$ ansible-playbook -i inventory.ini k8s-dependencies.yml
```

verify everything:
```
lsmod | grep br_netfilter
lsmod | grep overlay

sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv4.ip_forward

getenforce

firewall-cmd --list-ports
```

this playbook will:
1. load and persist these kernel modules `br_netfilter` & `overlay`.
2. apply these kernel parameters:
    * `net.bridge.bridge-nf-call-iptables = 1`
    * `net.bridge.bridge-nf-call-ip6tables = 1`
    * `net.ipv4.ip_forward = 1`
3. disables SELinux (until its compatible with k8s cluster)
4. enable these firewalld ports in `control-plane` nodes:
    - 6443/tcp
    - 2379-2380/tcp
    - 10250/tcp
    - 10251/tcp
    - 10252/tcp
5. enable these firewalld ports in `worker` nodes:
    - 10250/tcp
    - 30000-32767/tcp
6. enable this port in `load balancer` nodes:
    - 6443/tcp















### sources
- `https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/`
- `https://pro.tecmint.com/blog/deploy-kubernetes-cluster-kubeadm-rocky-linux/`
- `https://www.digitalocean.com/community/tutorials/how-to-create-a-kubernetes-cluster-using-kubeadm-on-centos-7`