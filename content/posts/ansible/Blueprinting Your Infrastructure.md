---
title: "Blueprinting Your Infrastructure"
date: 2026-05-05
draft: false
tags: ["ansible", "automation", "yaml", "playbook", "inventory", "devops", "infrastructure-as-code"]
description: "A beginner-friendly guide to Ansible fundamentals — what it is, how plays and tasks work, YAML syntax, inventory files, patterns, modules, and running your first playbook."
showToc: true
tocOpen: true
comments: true
---

# Chapter 1: Blueprinting Your Infrastructure

Think of Ansible like a **recipe book for your servers**.  
Instead of logging into 10 machines one by one and doing the same thing, you write the recipe once — and Ansible does it everywhere at the same time.

---

## 1. Getting Introduced to Ansible

**What is Ansible?**

Ansible is an open-source automation tool that lets you:
- Configure servers
- Deploy applications
- Orchestrate complex workflows

**The big idea:** You describe *what you want*, not *how to do it*. Ansible figures out the "how".

**Why Ansible over scripts?**

| Feature | Bash Script | Ansible |
|---|---|---|
| Easy to read | ❌ Hard | ✅ YAML |
| Idempotent (safe to re-run) | ❌ Manual work | ✅ Built-in |
| Works on many servers at once | ❌ Complex | ✅ Easy |
| No agent on target machine | ❌ Varies | ✅ Just SSH |

**How Ansible connects to your servers:**

```
Your Machine (Control Node)
        │
        │ SSH (no agent needed on the server!)
        ▼
   Server 1  ──┐
   Server 2  ──┤  ← These are called "Managed Nodes"
   Server 3  ──┘
```

---

## 2. Plays

A **play** is the heart of Ansible.  
Think of it as: *"For these specific servers, run these specific tasks."*

**Simple analogy:**  
> "Hey web servers — make sure Nginx is installed and running."

That's a play. It targets a group of servers and defines what should happen on them.

**A play always has at minimum:**
- `hosts` → Who should I run this on?
- `tasks` → What should I do?

```yaml
# This is a single "play"
- hosts: webservers       # Target: servers in the "webservers" group
  tasks:                  # What to do on those servers:
    - name: Say hello     # A human-readable label for this task
      debug:              # The "debug" module just prints a message
        msg: "Hello from Ansible!"
```

A **playbook** is just a file that contains **one or more plays**.

---

## 3. YAML – The Playbook Language

Ansible playbooks are written in **YAML** (Yet Another Markup Language).  
YAML is designed to be easy to read — it looks almost like plain English.

### YAML Rules to Remember

```yaml
# --- marks the start of a YAML file (optional but good practice)
---

# A simple key-value pair
name: Karim
city: Casablanca

# A list (notice the dashes)
fruits:
  - apple
  - banana
  - mango

# A nested structure (indentation = hierarchy)
server:
  name: web01
  ip: 192.168.1.10
  port: 80

# Boolean values
enabled: true
debug: false

# Multiline string
message: |
  This is line 1
  This is line 2
  This is line 3
```

### ⚠️ YAML Pitfalls

```yaml
# ❌ WRONG: mixing tabs and spaces will break everything
name:	Karim   # <- this is a TAB, not spaces!

# ✅ CORRECT: always use spaces (2 or 4, be consistent)
name: Karim

# ❌ WRONG: forgetting the space after the colon
name:Karim

# ✅ CORRECT
name: Karim
```

---

## 4. First Playbook

Let's write your very first Ansible playbook — it will ping all your servers to check they're reachable.

### File: `first_playbook.yml`

```yaml
---
# Every playbook starts with ---

- name: My First Playbook          # A friendly name for this play (shows in output)
  hosts: all                        # Target ALL servers in your inventory
  gather_facts: false               # Skip collecting server info (faster for simple tasks)

  tasks:                            # List of things to do

    - name: Check if servers respond  # Label for this task
      ping:                           # The "ping" module — Ansible's version of a connectivity test
                                      # It's NOT the network ping command, it tests Ansible connectivity
```

**Run it:**
```bash
ansible-playbook first_playbook.yml
```

**Expected output:**
```
PLAY [My First Playbook] ****************************

TASK [Check if servers respond] *********************
ok: [web01]
ok: [web02]
ok: [db01]

PLAY RECAP ******************************************
web01   : ok=1  changed=0  failed=0
web02   : ok=1  changed=0  failed=0
db01    : ok=1  changed=0  failed=0
```

---

## 5. Creating a Host Inventory

The **inventory** is the list of servers Ansible will manage.  
Think of it as your **phone book of servers**.

### Simple INI Format (Beginner-Friendly)

```ini
# File: inventory.ini

# --- Ungrouped servers (Ansible can reach these directly)
192.168.1.5

# --- A group called "webservers"
[webservers]
web01.example.com
web02.example.com
192.168.1.10          # You can also use IP addresses

# --- A group called "dbservers"
[dbservers]
db01.example.com
db02.example.com

# --- A group that CONTAINS other groups
[production:children]
webservers             # production = webservers + dbservers
dbservers

# --- Variables for a whole group
[webservers:vars]
http_port=80           # Every server in "webservers" gets this variable
ansible_user=ubuntu    # SSH as "ubuntu" on all webservers
```

### YAML Format (More Powerful)

```yaml
# File: inventory.yml
---
all:                              # "all" is the root group — contains everything
  children:                       # Subgroups live here

    webservers:                   # Group name
      hosts:                      # Servers in this group
        web01:
          ansible_host: 192.168.1.10   # The actual IP to connect to
          ansible_user: ubuntu         # SSH user
        web02:
          ansible_host: 192.168.1.11
          ansible_user: ubuntu

    dbservers:
      hosts:
        db01:
          ansible_host: 192.168.1.20
          ansible_user: admin
```

### Tell Ansible to use your inventory:

```bash
# Use -i to specify your inventory file
ansible-playbook -i inventory.ini my_playbook.yml

# Or set it permanently in ansible.cfg
```

### `ansible.cfg` — Your Ansible Config File

```ini
# File: ansible.cfg (place it in your project folder)

[defaults]
inventory = ./inventory.ini    # Default inventory to use
remote_user = ubuntu           # Default SSH user
host_key_checking = False      # Skip SSH fingerprint verification (useful in labs)
```

---

## 6. Patterns

Patterns let you **target specific servers or groups** without editing your playbook.

```yaml
# In your playbook, "hosts:" accepts patterns:

hosts: all                    # Every server in inventory
hosts: webservers             # Only the "webservers" group
hosts: webservers,dbservers   # Both groups combined
hosts: web01                  # One specific server
hosts: webservers:!web02      # webservers group, BUT excluding web02
hosts: webservers:&dbservers  # Servers that are in BOTH groups (intersection)
hosts: web*                   # Wildcard — any host starting with "web"
hosts: 192.168.1.*            # Wildcard on IP range
```

**On the command line, you can also override with `-l`:**

```bash
# Run the playbook, but only on web01
ansible-playbook site.yml -l web01

# Run on the webservers group only
ansible-playbook site.yml -l webservers

# Run on web01 AND web02
ansible-playbook site.yml -l "web01,web02"
```

---

## 7. Tasks

A **task** is a single unit of work — one thing Ansible does on a server.

```yaml
tasks:

  # --- Basic task structure
  - name: Install Nginx              # Human-readable description (always include this!)
    apt:                             # Module to use
      name: nginx                    # Module argument: what package to install
      state: present                 # "present" = make sure it's installed

  # --- Task with multiple arguments
  - name: Create a config directory
    file:                            # The "file" module manages files and directories
      path: /etc/myapp               # Path to create
      state: directory               # "directory" = make sure it's a folder
      owner: root                    # Who owns it
      group: root
      mode: '0755'                   # Permissions (rwxr-xr-x)

  # --- Task that runs a shell command (use sparingly — prefer dedicated modules)
  - name: Check disk space
    command: df -h                   # Runs "df -h" on the remote server

  # --- Task with a conditional (only run if...)
  - name: Restart Nginx on Debian
    service:
      name: nginx
      state: restarted
    when: ansible_os_family == "Debian"   # Only runs on Debian/Ubuntu servers

  # --- Task with a loop (repeat for multiple items)
  - name: Install multiple packages
    apt:
      name: "{{ item }}"             # "{{ item }}" is replaced by each value in the loop
      state: present
    loop:                            # Repeat this task for each item in the list
      - nginx
      - curl
      - git
```

---

## 8. Modules

**Modules** are the building blocks of Ansible tasks.  
Each module is a specialized tool for one job.

Think of them like kitchen tools: you use a knife for cutting, a pan for frying — not a fork for everything.

### Most Used Modules

#### `apt` — Install packages (Ubuntu/Debian)

```yaml
- name: Install nginx
  apt:
    name: nginx          # Package name
    state: present       # present = install, absent = uninstall, latest = upgrade
    update_cache: yes    # Run "apt update" before installing (like apt-get update)
```

#### `yum` / `dnf` — Install packages (CentOS/RHEL/Fedora)

```yaml
- name: Install httpd
  yum:
    name: httpd
    state: present
```

#### `service` — Manage services (start, stop, enable)

```yaml
- name: Start and enable Nginx
  service:
    name: nginx
    state: started       # started / stopped / restarted / reloaded
    enabled: yes         # Start automatically on boot
```

#### `copy` — Copy a file to the remote server

```yaml
- name: Copy config file
  copy:
    src: files/nginx.conf      # Path on YOUR machine (the control node)
    dest: /etc/nginx/nginx.conf # Where to put it on the remote server
    owner: root
    group: root
    mode: '0644'               # Permissions: rw-r--r--
```

#### `template` — Copy a file but replace variables inside it

```yaml
- name: Deploy nginx config with variables
  template:
    src: templates/nginx.conf.j2   # Jinja2 template file (.j2 extension)
    dest: /etc/nginx/nginx.conf
    mode: '0644'
```

#### `file` — Manage files, directories, symlinks

```yaml
- name: Create a directory
  file:
    path: /var/www/myapp
    state: directory    # directory / file / absent / touch / link
    mode: '0755'

- name: Delete a file
  file:
    path: /tmp/old_file.txt
    state: absent       # "absent" = make sure it does NOT exist
```

#### `user` — Manage Linux users

```yaml
- name: Create deploy user
  user:
    name: deploy          # Username
    shell: /bin/bash      # Default shell
    groups: sudo          # Add to sudo group
    create_home: yes      # Create /home/deploy/
    state: present
```

#### `debug` — Print messages (great for troubleshooting)

```yaml
- name: Show a variable
  debug:
    msg: "The server IP is: {{ ansible_host }}"

- name: Show entire variable structure
  debug:
    var: ansible_facts   # Dumps the variable content directly
```

#### `command` vs `shell` — Run commands

```yaml
# "command" — runs a command directly (safer, no shell features)
- name: Check uptime
  command: uptime

# "shell" — runs through /bin/sh (use when you need pipes, redirects, etc.)
- name: Count log lines
  shell: cat /var/log/nginx/access.log | wc -l   # pipe | requires shell
```

---

## 9. Running the Playbook

### Basic Run

```bash
# Syntax:
ansible-playbook -i <inventory> <playbook.yml>

# Example:
ansible-playbook -i inventory.ini site.yml
```

### Useful Flags

```bash
# Dry run — show what WOULD happen without making any changes
ansible-playbook site.yml --check

# Verbose output — see more details (use -vvv for maximum detail)
ansible-playbook site.yml -v
ansible-playbook site.yml -vvv

# Limit to specific hosts or groups
ansible-playbook site.yml -l webservers

# Pass extra variables at runtime
ansible-playbook site.yml -e "env=production version=1.5"

# Ask for SSH password (when not using SSH keys)
ansible-playbook site.yml --ask-pass

# Ask for sudo password (when tasks need privilege escalation)
ansible-playbook site.yml --ask-become-pass

# Check syntax only — validate YAML before running
ansible-playbook site.yml --syntax-check

# List all hosts the playbook would target (without running anything)
ansible-playbook site.yml --list-hosts

# List all tasks in the playbook (without running anything)
ansible-playbook site.yml --list-tasks
```

### Complete Example: Full Working Playbook

```yaml
---
# File: site.yml
# Goal: Install and start Nginx on all web servers

- name: Setup Web Servers           # Name of the play
  hosts: webservers                  # Target the "webservers" group
  become: yes                        # Run tasks with sudo (privilege escalation)
  become_user: root                  # Escalate to root

  vars:                              # Variables defined at play level
    http_port: 80                    # We'll use this later in configs
    max_clients: 200

  tasks:

    - name: Update apt package cache   # Always update before installing
      apt:
        update_cache: yes
        cache_valid_time: 3600         # Only update if cache is older than 1 hour

    - name: Install Nginx
      apt:
        name: nginx
        state: present                 # Make sure it's installed

    - name: Make sure Nginx is started and enabled
      service:
        name: nginx
        state: started                 # Start the service now
        enabled: yes                   # Also start it automatically on reboot

    - name: Print confirmation
      debug:
        msg: "Nginx is installed and running on {{ inventory_hostname }}"
        # inventory_hostname is a built-in variable = the name of the current host
```

**Run it:**
```bash
ansible-playbook -i inventory.ini site.yml
```

**What each status means in the output:**

| Status | Meaning |
|---|---|
| `ok` | Task ran, nothing needed to change |
| `changed` | Task ran and made a change |
| `failed` | Task ran and something went wrong |
| `skipped` | Task was skipped (e.g. `when:` condition was false) |
| `unreachable` | Couldn't connect to the server |

---

## Summary

| Concept | What It Is | Quick Example |
|---|---|---|
| **Ansible** | Automation tool over SSH | No agents needed |
| **Play** | "Do X on these servers" | `hosts: webservers` |
| **Playbook** | File with one or more plays | `site.yml` |
| **YAML** | Language for writing playbooks | Key-value, indented |
| **Inventory** | Your list of servers | `inventory.ini` |
| **Pattern** | How to target servers | `all`, `web*`, `!web02` |
| **Task** | One unit of work | Install nginx |
| **Module** | The tool used in a task | `apt`, `service`, `copy` |
