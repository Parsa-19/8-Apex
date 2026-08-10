install vim and then the package manager of python which contains the official ansible in it and then install ansible:
```
dnf install vim
dnf install -y python3 python3-pip
pip install --upgrade pip
pip install ansible
```

create a ssh key pair for root user in `cp-1` where we want to run ansible-playbooks and control cluster. then copy the ssh pub key to all nodes:
```
$ root@CP-1> ssk-keygen
$ root@CP-1> ssh-copy-id parsa@192.168.16.118 (same CP-1)
$ root@CP-1> ssh-copy-id parsa@192.168.16.119
$ root@CP-1> ssh-copy-id parsa@192.168.16.120
$ root@CP-1> ssh-copy-id parsa@192.168.16.121
$ root@CP-1> ssh-copy-id parsa@192.168.16.122
$ root@CP-1> ssh-copy-id parsa@192.168.16.123
$ root@CP-1> ssh-copy-id parsa@192.168.16.124
```

same for user parsa on `cp-1`:
```
$ parsa@CP-1> ssk-keygen
$ parsa@CP-1> ssh-copy-id parsa@192.168.16.118 (same CP-1)
$ parsa@CP-1> ssh-copy-id parsa@192.168.16.119
$ parsa@CP-1> ssh-copy-id parsa@192.168.16.120
$ parsa@CP-1> ssh-copy-id parsa@192.168.16.121
$ parsa@CP-1> ssh-copy-id parsa@192.168.16.122
$ parsa@CP-1> ssh-copy-id parsa@192.168.16.123
$ parsa@CP-1> ssh-copy-id parsa@192.168.16.124
```

to test the ansible:

create a sample `inventory.ini`:
```
[nodes]
192.168.16.118          ansible_connection=ssh        ansible_user=parsa
192.168.16.119          ansible_connection=ssh        ansible_user=parsa
192.168.16.120          ansible_connection=ssh        ansible_user=parsa
192.168.16.121          ansible_connection=ssh        ansible_user=parsa
192.168.16.122          ansible_connection=ssh        ansible_user=parsa
192.168.16.123          ansible_connection=ssh        ansible_user=parsa
192.168.16.124          ansible_connection=ssh        ansible_user=parsa
``` 

ping agent nodes:
```
$ parsa@CP-1> ansible nodes -m ping -i inventory.ini
```

for ansible to be able ro run commands as sudo add this after you ran `sudo visudo -f /etc/sudoers.d/parsa` on all agent nodes:
```
parsa ALL=(ALL) NOPASSWD: ALL
```

then you can play the palybook that needs sudo access:
```
parsa@CP-1> ansible-palybook -i inventory.ini palybook.yml
```