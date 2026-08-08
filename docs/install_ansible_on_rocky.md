dns change to 8.8.8.8 8.8.4.4 1.1.1.1 1.0.0.1

su parsa
dnf install vim
dnf install -y python3 python3-pip
pip install --upgrade pip
pip install ansible

root@CP-1> ssk-keygen
root@CP-1> ssh-copy-id parsa@192.168.55.118 (same CP-1)
root@CP-1> ssh-copy-id parsa@192.168.55.119
root@CP-1> ssh-copy-id parsa@192.168.55.120
root@CP-1> ssh-copy-id parsa@192.168.55.121
root@CP-1> ssh-copy-id parsa@192.168.55.122
root@CP-1> ssh-copy-id parsa@192.168.55.123

parsa@CP-1> ssk-keygen
parsa@CP-1> ssh-copy-id parsa@192.168.55.118 (same CP-1)
parsa@CP-1> ssh-copy-id parsa@192.168.55.119
parsa@CP-1> ssh-copy-id parsa@192.168.55.120
parsa@CP-1> ssh-copy-id parsa@192.168.55.121
parsa@CP-1> ssh-copy-id parsa@192.168.55.122
parsa@CP-1> ssh-copy-id parsa@192.168.55.123

inventory.ini:
```
[nodes]
192.168.55.118          ansible_connection=ssh        ansible_user=parsa
192.168.55.119          ansible_connection=ssh        ansible_user=parsa
192.168.55.120          ansible_connection=ssh        ansible_user=parsa
192.168.55.121          ansible_connection=ssh        ansible_user=parsa
192.168.55.122          ansible_connection=ssh        ansible_user=parsa
192.168.55.123          ansible_connection=ssh        ansible_user=parsa
```

parsa@CP-1> ansible nodes -m ping -i inventory.ini

do this on all agent nodes:
sudo visudo -f /etc/sudoers.d/parsa
parsa ALL=(ALL) NOPASSWD: ALL

then you can play palybooks that needs sudo access:
parsa@CP-1> ansible-palybook -i inventory.ini palybook.yml