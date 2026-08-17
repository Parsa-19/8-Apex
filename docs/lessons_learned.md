
### seprate ansible user 
define a seprate user for ansible on each node and grant just the needed permissions to that user in a custom seprate sudo file. so ansible user is permitted to run some sudo commands without asking for password.

in this example the ansible user can run any sudo command without asking for password.
> [!NOTE]
> not a good practice to set NOPASSWD for ansible user. you better define the exact needed actions to be permitted for ansible user.

on each agent node you would:
```
$ visudo -f /etc/sudoers.d/ansible

  ansible ALL=(ALL) NOPASSWD: ALL
```

---

