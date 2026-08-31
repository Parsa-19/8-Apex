## prerequisites on each node:
* 2 GB or more of RAM
* 2 CPUs or more
* Unique hostname, MAC address, and product_uuid for every node
 
---

## verify MAC address and product_uuid

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

## turn off swap on each node

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

## configure ansible to run playbooks

we manage and run ansible playbooks from `CP-1`.
```
$ mkdir ansible-plays
```

create an `inventory.ini` file with the content from here [inventory.ini](https://github.com/Parsa-19/8-Apex/blob/sherkat/ansible/inventory.ini):

first install required ansible collections:
```
$ ansible-galaxy collection install community.general
$ ansible-galaxy collection install ansible.posix
``` 

create another file named `k8s-dependencies.yml` to install and configure all dependencies from this file ([k8s-dependencies.yml](https://github.com/Parsa-19/8-Apex/blob/sherkat/ansible/k8s-dependencies.yml)).

run the playbook:
```
$ ansible-playbook -i inventory.ini k8s-dependencies.yml
```

verify everything:
```
$ lsmod | grep br_netfilter
$ lsmod | grep overlay

$ sysctl net.bridge.bridge-nf-call-iptables
$ sysctl net.ipv4.ip_forward

$ getenforce

$ firewall-cmd --list-ports
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

---

## install initial packages for the life
specifically for my rocky v10.2 minimal I have litterally nothing in my OS so wrote a mini playbook to install packages (like tar, unzip, vim and etc...) on all nodes:

[needed-initial-packages.yml](https://github.com/Parsa-19/8-Apex/blob/sherkat/ansible/needed-initial-packages.yml)

run to insatll:
```
$ ansible-playbook -i inventory.ini needed-initial-packages.yml
```

---

## install kubelet, kubeadm and containerd on CPs and workers

for that I downloaded each of the binary files and used an ansible playbook to install and configure them on dedicated nodes offline.

use this playbook [install-kubernetes-runtime-and-tools.yml](https://github.com/Parsa-19/8-Apex/blob/sherkat/ansible/install-kubernetes-runtime-and-tools.yml) and run it:
```
$ ansible-playbook -i inventory.ini install-kubernetes-runtime-and-tools.yml
```

that gives you a clean two-play playbook structure like this:
```
Play 1:
  cp-1
  cp-2
  cp-3
  node-1
  node-2

  - containerd
  - runc
  - CNI
  - crictl
  - kubelet
  - kubeadm


Play 2:
  cp-1 only

  - kubectl
```

to understand the playbook first consider the working dir which is used to install the components like this:

I am going to create this file-structure-diagram hierarchy here and also complete it in later steps.

<img src="../diagrams/file-structure-diagram.png" alt="Kubernetes project file structure diagram" width="600">

now you can understand how the playbook works:
#### first playbook named `Install Kubernetes dependencies` on all k8s nodes:
1. first it configures variables about **versions, local downloaded bin file names, installation paths and temp dir** to be used inside the playbook itself.
2. creates the basic directories:
    * the temp folder that holds data while installing `/tmp/k8s-install`.
    * containerd configuration dir `/etc/containerd`.
    * installation dir for CNI plugins `/opt/cni/bin` (needed by containerd).
    * CNI configuration directory `/etc/cni/net.d`.
3. copies the **containerd** bin file to dedicated node with `0644` permissions and:
    * install it by unarchiving it to `/usr/local`
4. copies the **runc** bin file to dedicated node with `0755` permissions and:
    * install it by copying it to `/usr/local/sbin/runc` and ensures the `0755` perms too.
5. copies the **CNI plugins** bin file to dedicated node with `0644` permissions and:
    * install it by unarchiving it to `/opt/cni/bin`.
6. copies the **crictl** bin file to dedicated node with `0644` permissions and:
    * install it by unarchiving it to `/usr/local/bin/crictl` and ensures the `0755` perms too.
7. installs the **containerd systemd service** by:
    * creating this dir `/usr/local/lib/systemd/system` with perm `0755`.
    * and download the service file from `https://raw.githubusercontent.com/containerd/containerd/main/containerd.service`.
    * and put the content in `/usr/local/lib/systemd/system/containerd.service` with perm `0644`.
8. use prepared **containerd-config.toml** file as ansible template.
    * copies it to `/etc/containerd/config.toml` with perms `0644`.
    * this file is already configured with systemdCgroups (dedicated for containerd 2.x configurations):
        ```
        [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
        SystemdCgroup = true
        ```
    * then restarts the containerd
9. Ensure **CRI is enabled**
10. **configures the crictl** conf file `/etc/crictl.yaml` with perms `0644` with content:
    ```
    runtime-endpoint: unix:///run/containerd/containerd.sock
    image-endpoint: unix:///run/containerd/containerd.sock
    timeout: 10
    debug: false    
    ```
11. after that all **reloads the systemd**.
12. **enables and starts containerd service**.
13. to install **kubelet** ansible copies the bin file to `/usr/local/bin/kubelet` with perms `0755`.
14. to install **kubeadm** ansible copies the bin file to `/usr/local/bin/kubeadm` with perms `0755`.
15. installs **kubelet service** by:
    * creating service file in `/etc/systemd/system/kubelet.service` with perms `0644` with this content:
        ```
        [Unit]
        Description=kubelet: The Kubernetes Node Agent
        Documentation=https://kubernetes.io/docs/
        Wants=network-online.target
        After=network-online.target

        [Service]
        ExecStart=/usr/local/bin/kubelet
        Restart=always
        RestartSec=10
        StartLimitIntervalSec=0

        [Install]
        WantedBy=multi-user.target
        ```
16. **reloads systemd**
17. **enables kubelet**
18. then there is bunch of tasks to get the version of each component and registers them in variables
19. registers the **status of containerd**
20. **displays all the versions** 
21. at the end of first playbook there is restart contianerd handler that's been used in step 8.

#### second playbook named `Install kubectl on cp-1` on cp-1:
22. copies the **kubectl** bin file to `/usr/local/bin/kubectl` with perms `0755`.
23. get **kubectl version** and registers the variable.
24. **displays kubectl version**.

#### download refrences:
* containerd v2.3.4 --> `https://github.com/containerd/containerd/releases/download/v2.3.4/containerd-2.3.4-linux-amd64.tar.gz`
* containerd.service file --> `https://raw.githubusercontent.com/containerd/containerd/main/containerd.service`
* runc v1.5.1 --> `https://github.com/opencontainers/runc/releases/download/v1.5.1/runc.amd64`
* CNI plugin v1.9.1 --> `https://github.com/containernetworking/plugins/releases/download/v1.9.1/cni-plugins-linux-amd64-v1.9.1.tgz`
* crictl v1.36.0 --> `https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.36.0/crictl-v1.36.0-linux-amd64.tar.gz`
* kubelet --> `https://dl.k8s.io/v1.36.2/bin/linux/amd64/kubelet`
* kubeadm --> `https://dl.k8s.io/v1.36.2/bin/linux/amd64/kubeadm`
* kubectl --> `https://dl.k8s.io/v1.36.2/bin/linux/amd64/kubectl`

---

## download all k8s necessary component images as tar files and import them

1. I will download the initial k8s needed images by a script which first use ctr to pull and then export images to a tar file. I will run this on cp-1 node.<br>
you can check out these initial images by:
    ```
    $ kubeadm config images list --kubernetes-version=v1.36.2
    ```

2. then use ansible to copy image tar files to all nodes (copy all images incase I want to turn a worker to control plane later; plus these images are light weight).

3. create a script file to import all image tar files on each node.

4. instead of running import script manually on each node I use another anisble playbook to run the import script and import the image tar files to containerd on each node.

> [!Caution]
> these images must be imported to k8s.io namespace which will be done in later steps sequence.

> [!TIP]
> `ctr` tool is available through `containerd-2.3.4-linux-amd64.tar.gz` package bundle I have installed.

> [!Important]
> as I explained in previous part the diagram file structure [file-structure-diagram.png](https://github.com/Parsa-19/8-Apex/blob/sherkat/diagrams/file-structure-diagram.png) is now what I am going to complete the it here. so take a look at the diagram again and create files like that in your working directory.
> and also in my case the root of my project is in `/root/8-Apex`.

#### first is the script that downloads k8s images
download this script file [download-k8s-images.sh](https://github.com/Parsa-19/8-Apex/blob/sherkat/scripts/download-k8s-images.sh) into `/root/8-Apex/k8s-images/download-k8s-images.sh`.

give it the execute perm and run it:
```
$ chmod +x download-k8s-images.sh
$ ./download-k8s-images.sh
```
this pulles images to k8s.io namespace in cp-1 (where you had ran this script on) and exports the image files to tar files to import them in rest of control planes.<br>
this also write image names that have been pulled and downloaded to a new file in the same dir named `images.txt`.
 
#### writing an ansible-playbook to distribute image files
download ansible-playbook file [k8s-distribute-images.yml](https://github.com/Parsa-19/8-Apex/blob/sherkat/ansible/k8s-distribute-images.yml) into `/root/8-Apex/ansible/k8s-distribute-images.yml`.

run the playbook from cp-1:
```
$ ansible-playbook -i inventory.ini k8s-distribute-images.yml
```

#### create another script file to import tar images
download the script file [import-k8s-images.sh](https://github.com/Parsa-19/8-Apex/blob/sherkat/scripts/import-k8s-images.sh) into `/root/8-Apex/k8s-images/import-k8s-images.sh`.

give it exec permissions:
```
$ chmod +x import-k8s-images.sh
```

*it will be used in another ansible playbook to be copied and run on all cluster nodes*.

#### create ansible playbook to run import script on all cluster nodes
download the file [import-k8s-images.yml](https://github.com/Parsa-19/8-Apex/blob/sherkat/ansible/import-k8s-images.yml) into `/root/8-Apex/ansible/import-k8s-images.yml`.

run the playbook:
```
$ ansible-playbook -i inventory.ini import-k8s-images.yml
```

after all you can verify the image importing on all nodes by listing them:
```
$ crictl images
```

---

## init the cluster
use cilium you need pull images specified for cilium on all nodes
use kubeadm init config.yml file
use kubeadm join control-plane config.yml file
use kubeadm join worker config.yml file
use kubevip pull image for kube-vip on all control planes

before init ensure that the kubelet and containerd services are working properly.

important fixes:
- kubelet service file:
  ```
  [Unit]
  Description=kubelet: The Kubernetes Node Agent
  Documentation=https://kubernetes.io/docs/
  Wants=network-online.target
  After=network-online.target
  After=containerd.service cri-o.service
  Requires=containerd.service cri-o.service
  
  [Service]
  ExecStart=/usr/local/bin/kubelet
  Restart=always
  RestartSec=10
  StartLimitIntervalSec=0
  
  [Install]
  WantedBy=multi-user.target
  ```
- kubelet default config file
  ```
  $ kubeadm config print init-defaults --component-configs KubeletConfiguration > /var/lib/kubelet/config.yaml
  ```
  Create the Configuration Drop-In Directory (Optional but Recommended):
  ```
  $ sudo mkdir -p /etc/systemd/system/kubelet.service.d
  $ cat << EOF > /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
  [Service]
  Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc>
  Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
  # This file is generated by 'kubeadm init' and 'kubeadm join' at runtime
  EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
  # This file can be used for manual user overrides
  #EnvironmentFile=-/etc/default/kubelet
  ExecStart=
  ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
  EOF
  ```
  or just use this [kubelet.service](https://github.com/Parsa-19/8-Apex/blob/sherkat/kubernetes/kubelet.service) file and system daemon-reload the system and restart the service.

the cluster would have this clean network design:
```
Node network:
192.168.55.0/24

Pod network:
10.244.0.0/16

Service network:
10.96.0.0/12
```

### kube-vip

first create this kube-vip.yaml manifest file and place it in `/etc/kubernetes/manifests/kube-vip.yaml` (create the directory if it doesnt exists). kubelet then use this manifests in this dir to create static pods and in initializing the cluster. create it by:

get latest kubevip version and use the exact version in your commands:
```
$ echo "$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")"
```

kube-vip v1.2.3 manifest by these commands:
```
$ export VIP=192.168.55.100
$ export INTERFACE=enp0s8
$ export KVVERSION=v1.2.3

$ alias kube-vip="ctr -n k8s.io image pull ghcr.io/kube-vip/kube-vip:$KVVERSION; ctr -n k8s.io run --rm --net-host ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip"

$ kube-vip manifest pod \
    --interface $INTERFACE \
    --address $VIP \
    --controlplane \
    --services \
    --arp \
    --leaderElection | tee /etc/kubernetes/manifests/kube-vip.yaml  
```
the above commands will create the kube-vip.yaml file but you need to change it a little bit.<br>
for example specify the use of `super-admin.conf` instead of `admin.conf` cause the kube-vip needs to access the cluster durring the setup and in newer version of kubeadm you have to do this to work. so use the [kube-vip.yaml file](https://github.com/Parsa-19/8-Apex/blob/sherkat/kubernetes/kube-vip.yaml) I created.

for the offline case in kube-vip also do these on rest of control planes:
- export the image to tar file.
- distribute it through all CP nodes
- import the kube-vip image
- copy the manifest to /etc/kubernetes/manifests/kube-vip.yaml

### create the cluster, add cp and workers
prepare [kubeadm-init.yml](https://github.com/Parsa-19/8-Apex/blob/sherkat/kubernetes/kubeadm-init.yml) config file and init the cluster.

initialize the cluster:
```
kubeadm init --config kubeadm-init.conf --upload-certs --v=5
```

install helm, cilium

prepare the kube-vip on other CPs, ensure that kubelet and conatinerd services works fine. in offline case ensure about the k8s and kube-vip images on each cp node. create the [cp-2-join.yml](https://github.com/Parsa-19/8-Apex/blob/sherkat/kubernetes/cp-2-join.yml) on cp-2 and [cp-3-join.yml](https://github.com/Parsa-19/8-Apex/blob/sherkat/kubernetes/cp-3-join.yml) on cp-3. then join cp-2 and cp-3 by this command:
```
cp-2$ kubeadm join --config cp-2-join.yml --v=5
cp-3$ kubeadm join --config cp-3-join.yml --v=5
```

to prepare workers before join. ensure the kubelet and containerd services works fine. again for offline case ensure k8s images exists on nodes.

join worker nodes:
```
worker-1$ kubeadm join --config node-1-join.yml --v=5
worker-2$ kubeadm join --config node-2-join.yml --v=5
```

on control plane get nodes to verify all nodes in cluster:
```
$ kubectl get nodes -o wide
```


### t-shoot and test commands
reset everything and prepare to init the cluster again:
```
kubeadm reset -f
```

You can verify the routing from the node and ensure it pass through enp0s8:
```
$ ip route get 192.168.55.119
```

create new fresh cluster cert:
```
$ sudo kubeadm init phase upload-certs --upload-certs --config kubeadm-init.yml --v=5
``` 

create fresh token:
```
$ kubeadm token create --print-join-command
```

you can check if the specific node can see or reach the VIP or not by:
```
$ ping -c 3 192.168.55.100 
$ nc -vz 192.168.55.100 6443
$ curl -k https://192.168.55.100:6443/version
``` 




## sources/guides
- `https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/`
- `https://pro.tecmint.com/blog/deploy-kubernetes-cluster-kubeadm-rocky-linux/`
- `https://www.digitalocean.com/community/tutorials/how-to-create-a-kubernetes-cluster-using-kubeadm-on-centos-7`
- `https://github.com/kubernetes/kubeadm/blob/main/docs/ha-considerations.md#options-for-software-load-balancing`
