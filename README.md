# Ansible SSH Users Management Role

This role manages SSH user accounts with role-based access control using sudo groups. It provides secure user management with different permission levels and SSH key authentication.

## Features

- **Role-based Access Control**: Ability to define groups and permissions
- **SSH Key Management**: Automated SSH key deployment and management
- **User Lifecycle Management**: Create, update, and remove users
- **Safe Pruning**: Optional removal of unmanaged users with safety checks

## Quick Start

### 1. Define Users in Variables

```yaml
# group_vars/all.yml or host_vars/
managed_users:
  - username: "john_doe"
    state: "present"
    group: "full_access"
    ssh_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGC5pOFM+2PSm3z2PA4A4y3gC9zJ+Jd7k8r7xW3bXy9z john@example.com"
  
  - username: "jane_smith"
    state: "present"
    group: "edit"
    ssh_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZ/K8jBKF2vAn4NEiZ6k0r/K8d7k3j2hL+xZo9gHq8L jane@example.com"
  
  - username: "read_only_user"
    state: "present"
    group: "readonly"
    ssh_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbLg+2bV8f4kY2bF2h4n8jK9gH/lK8e9bX3o2fJkL9o readonly@example.com"
  
  - username: "old_user"
    state: "absent"
```

### 2. Playbook

```yaml
- hosts: all
  become: yes
  roles:
    - role: role-ssh-users
```

### 3. Deploy

```bash
# Normal deployment
ansible-playbook -i inventory.ini your_playbook.yml --ask-become-pass
```

## Permission Levels

### User Groups and Sudo Access

The following groups are defined by default, but you can customize these or create your own groups by modifying the `sudo_commands` variable in your playbook variables.

| Group | Permissions | Sudo Commands |
|-------|-------------|---------------|
| `readonly` | Network read-only access | `/sbin/ip route show`, `/sbin/ip addr show`, `/sbin/ip link show`, `/sbin/iptables -L`, `/sbin/iptables -S`, `/bin/netstat` |
| `monitoring` | Network monitoring tools | `/usr/bin/nmap *`, `/usr/sbin/traceroute *`, `/bin/ping *`, `/usr/bin/dig *`, `/usr/bin/tcpdump`, `/usr/bin/nslookup *`, `/usr/bin/host *`, `/usr/bin/telnet *` |
| `edit` | Network configuration | `/sbin/ip route add/del *`, `/sbin/ip addr add/del *`, `/sbin/iptables -A/-D/-I/-F/-X *`, `/bin/systemctl restart/reload networking` |
| `full_access` | Administrative access | ALL commands (NOPASSWD) |

**Multi-Groups**: Users can be assigned to multiple groups (e.g., `groups: ["readonly", "monitoring"]`) to combine permissions from different groups.

**Custom Groups**: Define your own groups by adding them to the `sudo_commands` variable in `group_vars/` or `host_vars/` files.

## Variable Reference

#### `managed_users`
List of user accounts to manage. Each user object supports:
- `username`: User account name (required)
- `state`: `present` or `absent` (required)
- `group`: User group - `readonly`, `edit`, or `full_access` (required when state=present)
- `ssh_key`: SSH public key for authentication (optional)

#### `untouchable_users`
List of system users that should never be modified or removed:
```yaml
untouchable_users:
  - root
  - ansible
```

## User Management

### Adding Users
```yaml
managed_users:
  - username: "new_user"
    state: "present"
    group: "edit"
    ssh_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGC5pOFM+2PSm3z2PA4A4y3gC9zJ+Jd7k8r7xW3bXy9z new_user@example.com"
```

### Removing Users
```yaml
managed_users:
  - username: "old_user"
    state: "absent"
```

### Changing User Permissions
```yaml
managed_users:
  - username: "user_to_promote"
    state: "present"
    group: "full_access"  # Changed from readonly/edit
    ssh_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGC5pOFM+2PSm3z2PA4A4y3gC9zJ+Jd7k8r7xW3bXy9z user@example.com"
```

## Pruning Unmanaged Users

⚠️ **DANGEROUS OPERATION**: The pruning feature removes all non-system users that are not explicitly defined in your `managed_users` list.

### Safety Features
- Only affects users with UID ≥ 1000
- Respects `untouchable_users` list
- Requires explicit `--tags prune` to execute the removal of non controlled users

### Usage
```bash
# Review what would be removed (dry run)
ansible-playbook -i inventory.ini your_playbook.yml --ask-become-pass --tags prune --check

# Actually remove unmanaged users
ansible-playbook -i inventory.ini your_playbook.yml --ask-become-pass --tags prune
```

## Testing Examples

### Test Playbook
Basic role testing with example users:

```yaml
---
- name: Test SSH Users Role
  hosts: test_servers
  become: yes
  roles:
    - role: role-ssh-users 
```

### Test Pruning Playbook
Testing the pruning functionality with temporary users:

```yaml
---
- name: Test SSH Users Role with Pruning
  hosts: test_servers
  become: yes
  pre_tasks:
    - name: Create some unmanaged users for pruning test
      user:
        name: "{{ item }}"
        state: present
        create_home: true
        shell: /bin/bash
      loop:
        - "unmanaged_user1"
        - "unmanaged_user2"
        - "test_prune_user"
      tags: [prune]
        
  roles:
    - role: role-ssh-users 
      
  tasks:
    - name: Show all users with UID >= 1000
      shell: "awk -F: '$3 >= 1000 {print $1}' /etc/passwd"
      register: all_users
      
    - name: Display users
      debug:
        msg: "Users with UID >= 1000: {{ all_users.stdout_lines }}" 
```

### Test Inventory
SSH inventory configuration for testing:

```ini
[test_servers]
ansible-target ansible_host=127.0.0.1 ansible_port=2222 ansible_user=ansible ansible_password=ansible

[test_servers:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no' 
```

### Running Tests

#### Using Docker Compose
```bash
# Start the test container
docker-compose up -d

# Wait for container to be ready
sleep 5

# Normal test
ansible-playbook -i inventory-ssh.ini test-playbook.yml

# Pruning test
ansible-playbook -i inventory-ssh.ini test-pruning-playbook.yml --tags prune

# Stop the test container
docker-compose down
```