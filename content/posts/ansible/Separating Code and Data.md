---
title: "Separating Code and Data – Variables, Facts, and Templates"
date: 2026-05-05
draft: false
tags: ["ansible", "variables", "facts", "jinja2", "templates", "mysql", "nginx", "devops", "infrastructure-as-code"]
description: "A practical guide to separating your Ansible logic from your data — Jinja2 templates, automatic facts, user-defined variables, variable precedence, MySQL role creation, and best practices."
showToc: true
tocOpen: true
comments: true
---

In the previous section, we hard-coded values directly into our tasks.  
That works — until you need to run the same role on a **staging server** (port 8080) and a **production server** (port 80) with **different domain names**, **different paths**, and **different credentials**.

This tuto is about one core principle:

> **Keep your logic (code) separate from your values (data).**

---

## 1. Static Content Explosion

Imagine you have this config file hard-coded:

```ini
# /etc/nginx/nginx.conf — hard-coded values everywhere
server {
    listen 80;
    server_name myapp.com;
    root /var/www/myapp;
    error_log /var/log/nginx/error.log;
}
```

Now your manager says:
- Staging needs port `8080` and domain `staging.myapp.com`
- Production needs port `80` and domain `myapp.com`
- The client's server needs port `443` and domain `client.example.com`

**Without variables:** You copy the file 3 times, change it manually, and pray you don't make a mistake.  
**With variables:** You write the file once, and let Ansible fill in the right values per environment.

This manual copying is called **static content explosion** — your config files multiply out of control.

---

## 2. Separating Code and Data

The solution is simple: **replace hard-coded values with placeholders (variables)**.

```
BEFORE (everything mixed):               AFTER (cleanly separated):
─────────────────────────────────        ─────────────────────────────────
tasks/main.yml                           tasks/main.yml
  - apt: name=nginx                        - apt: name={{ web_package }}
  - listen 80                              - listen {{ nginx_port }}
  - root /var/www/myapp                    - root {{ nginx_root }}
                                         
                                         defaults/main.yml
                                           web_package: nginx
                                           nginx_port: 80
                                           nginx_root: /var/www/myapp
```

**Benefits:**
- One role, many environments
- Change a value in one place — it updates everywhere
- Non-technical teammates can edit the data (YAML) without touching the logic
- Easy to review what changes between environments

---

## 3. Jinja2 Templates

**Jinja2** is the templating engine Ansible uses to fill in variables inside files.

Think of it like a **form letter** — you write the letter once with blank fields, then fill in different names and addresses for each recipient.

The syntax is simple:

```jinja2
{# This is a Jinja2 comment — it won't appear in the output #}

{# --- Variable output --- #}
Hello, {{ username }}!                {# Prints the value of "username" #}

{# --- Filter: transform a value --- #}
{{ username | upper }}                {# Prints username in UPPERCASE #}
{{ username | default('guest') }}     {# Prints username, or 'guest' if undefined #}
{{ package_list | join(', ') }}       {# Joins a list into a comma-separated string #}

{# --- Conditional block --- #}
{% if nginx_ssl_enabled %}
    listen 443 ssl;
{% else %}
    listen {{ nginx_port }};
{% endif %}

{# --- Loop block --- #}
{% for vhost in nginx_vhosts %}
    server_name {{ vhost.name }};
{% endfor %}
```

**File naming convention:**  
Template files always end in `.j2` (short for Jinja2) to make them easy to spot:

```
templates/
├── nginx.conf.j2       ✅ clearly a template
├── my.cnf.j2           ✅ clearly a template
└── index.html          ❌ could be confused with a static file
```

---

## 4. The Template Formation

Here's how templates flow from your machine to the server:

```
Your Ansible Control Node                Remote Server
─────────────────────────────────        ─────────────────────────────────
roles/nginx/templates/nginx.conf.j2      /etc/nginx/nginx.conf
                │                                  ▲
                │    Ansible reads the .j2          │
                │    file, replaces all             │
                └──  {{ variables }} with  ─────────┘
                     real values, and
                     writes the result
```

**The `template` module** does this work:

```yaml
# In tasks/main.yml
- name: Deploy Nginx config file
  template:
    src: nginx.conf.j2              # Relative to roles/<name>/templates/
    dest: /etc/nginx/nginx.conf     # Full path on the remote server
    owner: root
    group: root
    mode: '0644'                    # Permissions: rw-r--r--
  notify: Reload Nginx              # Trigger handler if file changed
```

**vs the `copy` module** — key difference:

```yaml
# copy: sends the file AS-IS — no variable substitution
- name: Copy a static file
  copy:
    src: index.html                 # File from roles/<name>/files/
    dest: /var/www/html/index.html  # No {{ }} replacement happens

# template: fills in variables before sending
- name: Deploy a dynamic config
  template:
    src: nginx.conf.j2              # {{ variables }} get replaced
    dest: /etc/nginx/nginx.conf     # Result sent to server
```

---

## 5. Facts and Variables

In Ansible, **variables** are values you define or discover that can be used anywhere in your playbook.

There are two main categories:

| Type | Who Creates It | Examples |
|---|---|---|
| **Facts** | Ansible (automatic) | OS name, IP address, RAM, CPU count |
| **User-defined variables** | You | `nginx_port: 80`, `db_name: myapp` |

---

## 6. Automatic Variables – Facts

When Ansible connects to a server, it automatically **gathers facts** — a collection of information about that server.

You can see all facts for a host by running:

```bash
# Gather and display all facts for "web01"
ansible web01 -m setup

# Filter to only show network facts
ansible web01 -m setup -a "filter=ansible_eth*"
```

### Commonly Used Facts

```yaml
# OS and distribution
ansible_os_family          # "Debian", "RedHat", "Archlinux"...
ansible_distribution       # "Ubuntu", "CentOS", "Fedora"...
ansible_distribution_version  # "22.04", "8.5"...

# Network
ansible_hostname           # Short hostname: "web01"
ansible_fqdn               # Full hostname: "web01.example.com"
ansible_default_ipv4.address  # Primary IP: "192.168.1.10"
ansible_all_ipv4_addresses    # List of all IPv4 addresses

# Hardware
ansible_processor_count    # Number of CPUs: 4
ansible_memtotal_mb        # Total RAM in MB: 8192
ansible_architecture       # "x86_64", "aarch64"...

# Storage
ansible_mounts             # List of mounted filesystems
ansible_devices            # List of disk devices
```

### Using Facts in Tasks

```yaml
# Install the right package manager based on the OS
- name: Install curl
  package:                              # "package" works across distros
    name: curl
    state: present

# Or use facts to choose the right module
- name: Install nginx on Debian/Ubuntu
  apt:
    name: nginx
    state: present
  when: ansible_os_family == "Debian"  # Only run on Debian-based systems

- name: Install nginx on RedHat/CentOS
  yum:
    name: nginx
    state: present
  when: ansible_os_family == "RedHat"  # Only run on RedHat-based systems
```

### Using Facts in Templates

```jinja2
{# File: templates/motd.j2 — Message of the Day banner #}
===========================================
  Hostname : {{ ansible_hostname }}
  OS       : {{ ansible_distribution }} {{ ansible_distribution_version }}
  IP       : {{ ansible_default_ipv4.address }}
  CPUs     : {{ ansible_processor_count }}
  RAM      : {{ ansible_memtotal_mb }} MB
===========================================
  Managed by Ansible — do not edit manually
===========================================
```

### Disabling Fact Gathering (for speed)

```yaml
# If you don't use facts, disable gathering — saves ~2 seconds per host
- name: Quick play with no facts needed
  hosts: all
  gather_facts: false       # Skip fact gathering
  tasks:
    - name: Say hello
      debug:
        msg: "Hello!"
```

---

## 7. User-Defined Variables

These are variables **you create** to control your role's behavior.

### Inline Variables in a Task

```yaml
- name: Create directory
  file:
    path: /var/www/myapp    # Hard-coded — avoid this in roles
    state: directory
```

Better:

```yaml
- name: Create web root directory
  file:
    path: "{{ app_root }}"  # Variable — flexible and reusable
    state: directory
```

### Variables in `defaults/main.yml` (Recommended for most cases)

```yaml
# File: roles/nginx/defaults/main.yml
# Low-priority defaults — easy for users to override
---

nginx_port: 80
nginx_server_name: localhost
nginx_root: /var/www/html
nginx_index: "index.html index.htm"
nginx_worker_processes: auto
nginx_worker_connections: 1024
nginx_keepalive_timeout: 65
nginx_ssl_enabled: false          # Boolean: off by default
nginx_vhosts: []                  # Empty list by default
```

### Variables in `vars/main.yml` (For internal/fixed values)

```yaml
# File: roles/nginx/vars/main.yml
# High-priority internal values — not meant to be overridden by users
---

nginx_package: nginx
nginx_service: nginx
nginx_config_dir: /etc/nginx
nginx_pid_file: /run/nginx.pid
```

---

## 8. Where to Define a Variable

Variables can live in many places. Here's a map:

```
Project structure:
─────────────────────────────────────────────────────────────
inventory.ini                ← host_vars and group_vars inline
host_vars/
  web01.yml                  ← variables only for web01
  web02.yml                  ← variables only for web02
group_vars/
  all.yml                    ← variables for ALL hosts
  webservers.yml             ← variables for the "webservers" group
  dbservers.yml              ← variables for the "dbservers" group
roles/
  nginx/
    defaults/main.yml        ← role defaults (lowest priority)
    vars/main.yml            ← role internals (higher priority)
site.yml                     ← vars: block in the playbook
```

### `host_vars/` — Per-server variables

```yaml
# File: host_vars/web01.yml
# Only applies to the host named "web01"
---
nginx_port: 8080              # web01 runs on a non-standard port
nginx_server_name: dev.myapp.com
app_env: development
```

```yaml
# File: host_vars/web02.yml
# Only applies to "web02"
---
nginx_port: 80
nginx_server_name: myapp.com
app_env: production
```

### `group_vars/` — Per-group variables

```yaml
# File: group_vars/all.yml
# Applies to EVERY host in inventory
---
ntp_server: pool.ntp.org
admin_email: ops@mycompany.com
ansible_user: ubuntu
```

```yaml
# File: group_vars/webservers.yml
# Only applies to hosts in the "webservers" group
---
nginx_port: 80
nginx_root: /var/www/html
http_timeout: 30
```

```yaml
# File: group_vars/dbservers.yml
# Only applies to hosts in the "dbservers" group
---
mysql_port: 3306
mysql_max_connections: 200
mysql_innodb_buffer_pool_size: "512M"
```

---

## 9. How to Define a Variable

Multiple syntax options depending on context:

```yaml
# --- 1. Simple scalar (string, number, boolean)
app_name: myapp
http_port: 80
debug_mode: false

# --- 2. List
allowed_ports:
  - 22
  - 80
  - 443

# One-line list syntax (same thing)
allowed_ports: [22, 80, 443]

# --- 3. Dictionary (key-value map)
mysql_config:
  host: localhost
  port: 3306
  user: root
  password: "secretpassword"

# Access dictionary values with dot notation or bracket notation
# {{ mysql_config.host }}  or  {{ mysql_config['host'] }}

# --- 4. Multiline string
nginx_extra_config: |
  add_header X-Frame-Options DENY;
  add_header X-Content-Type-Options nosniff;

# --- 5. Registered variable (captured from a task's output)
- name: Check if nginx config is valid
  command: nginx -t                 # Run "nginx -t" on the server
  register: nginx_test_result       # Save the output in this variable

- name: Show the result
  debug:
    msg: "Nginx config test: {{ nginx_test_result.stdout }}"  # Print stdout
```

---

## 10. Templating the Nginx Configurations

Now let's put it all together — a real Nginx config that uses variables and Jinja2.

### The variables (defaults)

```yaml
# File: roles/nginx/defaults/main.yml
---

nginx_port: 80
nginx_server_name: localhost
nginx_root: /var/www/html
nginx_index: "index.html index.htm"
nginx_worker_processes: auto
nginx_worker_connections: 1024
nginx_keepalive_timeout: 65
nginx_client_max_body_size: "10m"
nginx_log_dir: /var/log/nginx
nginx_ssl_enabled: false
nginx_ssl_cert: /etc/ssl/certs/nginx.crt
nginx_ssl_key: /etc/ssl/private/nginx.key
nginx_extra_headers: []         # Empty by default — users can add custom headers
```

### The Jinja2 template

```jinja2
{# File: roles/nginx/templates/nginx.conf.j2 #}
{# Main Nginx configuration — generated by Ansible, do not edit manually #}

user www-data;

{# Use the variable — defaults to "auto" which lets nginx choose based on CPU count #}
worker_processes {{ nginx_worker_processes }};

pid /run/nginx.pid;

events {
    worker_connections {{ nginx_worker_connections }};
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    keepalive_timeout {{ nginx_keepalive_timeout }};
    client_max_body_size {{ nginx_client_max_body_size }};

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    {# Logging #}
    access_log {{ nginx_log_dir }}/access.log;
    error_log  {{ nginx_log_dir }}/error.log;

    server {
        {# Conditional: add SSL config only if ssl is enabled #}
        {% if nginx_ssl_enabled %}
        listen 443 ssl;
        ssl_certificate     {{ nginx_ssl_cert }};
        ssl_certificate_key {{ nginx_ssl_key }};
        ssl_protocols TLSv1.2 TLSv1.3;
        {% else %}
        listen {{ nginx_port }};
        {% endif %}

        server_name {{ nginx_server_name }};
        root {{ nginx_root }};
        index {{ nginx_index }};

        {# Loop: add custom headers if any are defined #}
        {% for header in nginx_extra_headers %}
        add_header {{ header }};
        {% endfor %}

        location / {
            try_files $uri $uri/ =404;
        }

        {# Add a redirect from HTTP to HTTPS only if SSL is enabled #}
        {% if nginx_ssl_enabled %}
    }

    server {
        listen {{ nginx_port }};
        server_name {{ nginx_server_name }};
        return 301 https://$host$request_uri;   {# Redirect all HTTP → HTTPS #}
        {% endif %}
    }
}
```

### The task that deploys it

```yaml
# File: roles/nginx/tasks/main.yml (excerpt)

- name: Deploy Nginx main configuration
  template:
    src: nginx.conf.j2              # Template from roles/nginx/templates/
    dest: /etc/nginx/nginx.conf     # Destination on the server
    owner: root
    group: root
    mode: '0644'
    validate: '/usr/sbin/nginx -t -c %s'   # Validate config BEFORE writing!
    # %s is replaced by a temp copy of the file
    # If "nginx -t" fails, Ansible aborts — the live config is never touched
  notify: Reload Nginx
```

---

## 11. Adding Another Layer – The MySQL Role

Web apps usually need a database. Let's add a MySQL role alongside Nginx.

**Architecture goal:**

```
site.yml
  ├── webservers.yml  →  roles: [base, nginx]
  └── dbservers.yml   →  roles: [base, mysql]
```

---

## 12. Creating the Scaffolding for the Roles with Ansible-Galaxy

Instead of creating folders manually, use `ansible-galaxy init`:

```bash
# Navigate to your project's roles directory
cd roles/

# Create the mysql role scaffold
ansible-galaxy init mysql
```

This generates the full structure instantly:

```
roles/mysql/
├── README.md
├── defaults/
│   └── main.yml       ← empty, ready for your defaults
├── files/             ← empty, for static files
├── handlers/
│   └── main.yml       ← empty, for handlers
├── meta/
│   └── main.yml       ← pre-filled with Galaxy metadata
├── tasks/
│   └── main.yml       ← empty, ready for tasks
├── templates/         ← empty, for Jinja2 templates
├── tests/
│   ├── inventory      ← simple test inventory
│   └── test.yml       ← simple test playbook
└── vars/
    └── main.yml       ← empty, for fixed vars
```

---

## 13. Adding Metadata to the Role

The `meta/main.yml` file describes your role — useful if you share it on Ansible Galaxy, and required for role dependencies.

```yaml
# File: roles/mysql/meta/main.yml
---

galaxy_info:
  role_name: mysql                          # Name on Ansible Galaxy
  author: karim                             # Your name
  description: "Installs and configures MySQL server"
  company: "MyCompany"
  license: MIT

  # Minimum Ansible version required
  min_ansible_version: "2.10"

  # Platforms this role supports
  platforms:
    - name: Ubuntu
      versions:
        - focal      # 20.04
        - jammy      # 22.04
    - name: Debian
      versions:
        - bullseye   # 11
        - bookworm   # 12

  # Tags for searchability on Galaxy
  galaxy_tags:
    - mysql
    - database
    - web

# Role dependencies — run these roles BEFORE mysql
dependencies:
  - role: base        # base must run first (updates, users, etc.)
```

---

## 14. Using Variables in Tasks and Handlers

### Creating Variables

```yaml
# File: roles/mysql/defaults/main.yml
# All MySQL defaults — override these per environment
---

mysql_port: 3306
mysql_bind_address: "127.0.0.1"        # Only listen on localhost by default (safer)
mysql_root_password: "changeme"         # ⚠️ Override this in production!
mysql_datadir: /var/lib/mysql
mysql_log_dir: /var/log/mysql
mysql_max_connections: 150
mysql_innodb_buffer_pool_size: "256M"
mysql_character_set: utf8mb4           # Full Unicode support
mysql_collation: utf8mb4_unicode_ci

# List of databases to create
mysql_databases: []

# List of users to create
mysql_users: []
```

```yaml
# File: roles/mysql/vars/main.yml
# Internal fixed values — not meant to be overridden
---

mysql_package: mysql-server
mysql_service: mysql
mysql_config_dir: /etc/mysql
mysql_config_file: /etc/mysql/mysql.conf.d/mysqld.cnf
mysql_socket: /var/run/mysqld/mysqld.sock
```

### Creating Tasks

```yaml
# File: roles/mysql/tasks/main.yml
---

# --- Install MySQL
- name: Install MySQL server
  apt:
    name: "{{ mysql_package }}"
    state: present
    update_cache: yes

# --- Ensure MySQL is started
- name: Start and enable MySQL service
  service:
    name: "{{ mysql_service }}"
    state: started
    enabled: yes

# --- Deploy config file
- name: Deploy MySQL configuration
  template:
    src: mysqld.cnf.j2                  # Jinja2 template (see below)
    dest: "{{ mysql_config_file }}"     # /etc/mysql/mysql.conf.d/mysqld.cnf
    owner: root
    group: root
    mode: '0644'
  notify: Restart MySQL                 # Restart if config changed

# --- Secure the root password
- name: Set MySQL root password
  mysql_user:                           # Ansible's built-in MySQL module
    name: root
    host: localhost
    password: "{{ mysql_root_password }}"  # From defaults (override in production!)
    login_unix_socket: "{{ mysql_socket }}"
    state: present

# --- Create application databases
- name: Create application databases
  mysql_db:                             # Module to manage MySQL databases
    name: "{{ item.name }}"            # Loop over the mysql_databases list
    state: present
    encoding: "{{ mysql_character_set }}"
    collation: "{{ mysql_collation }}"
    login_user: root
    login_password: "{{ mysql_root_password }}"
  loop: "{{ mysql_databases }}"         # Repeat for each database in the list
  when: mysql_databases | length > 0   # Only run if the list is not empty

# --- Create application users
- name: Create MySQL users
  mysql_user:
    name: "{{ item.name }}"
    password: "{{ item.password }}"
    priv: "{{ item.priv | default('*.*:USAGE') }}"   # default: minimal privileges
    host: "{{ item.host | default('localhost') }}"
    login_user: root
    login_password: "{{ mysql_root_password }}"
    state: present
  loop: "{{ mysql_users }}"
  when: mysql_users | length > 0
  no_log: true                          # ⚠️ Don't print passwords in output!
```

### The MySQL config template

```jinja2
{# File: roles/mysql/templates/mysqld.cnf.j2 #}
{# MySQL server configuration — generated by Ansible #}

[mysqld]
# --- Network
port            = {{ mysql_port }}
bind-address    = {{ mysql_bind_address }}    {# 127.0.0.1 = local only, 0.0.0.0 = all interfaces #}
socket          = {{ mysql_socket }}

# --- Storage
datadir         = {{ mysql_datadir }}

# --- Connection limits
max_connections = {{ mysql_max_connections }}

# --- InnoDB engine settings
innodb_buffer_pool_size = {{ mysql_innodb_buffer_pool_size }}

# --- Character set (use utf8mb4 for full emoji/Unicode support)
character-set-server  = {{ mysql_character_set }}
collation-server      = {{ mysql_collation }}

# --- Logging
log_error = {{ mysql_log_dir }}/error.log
slow_query_log = 1
slow_query_log_file = {{ mysql_log_dir }}/slow.log
long_query_time = 2     {# Log queries slower than 2 seconds #}
```

### Creating Handlers

```yaml
# File: roles/mysql/handlers/main.yml
---

# Handler: only runs when a task notifies it
- name: Restart MySQL
  service:
    name: "{{ mysql_service }}"
    state: restarted          # Full restart — use when config changes require it

- name: Reload MySQL
  service:
    name: "{{ mysql_service }}"
    state: reloaded           # Graceful reload — use when possible to avoid downtime
```

---

## 15. Using Variables in Playbooks

You can pass variables directly in your playbook — useful for one-off overrides.

```yaml
# File: dbservers.yml
---

- name: Configure Database Servers
  hosts: dbservers
  become: yes

  vars:                                 # Inline variables — override role defaults
    mysql_max_connections: 300          # This environment needs more connections
    mysql_innodb_buffer_pool_size: "1G" # More RAM available on db servers

    mysql_databases:                    # Define which databases to create
      - name: appdb
        encoding: utf8mb4
      - name: analyticsdb
        encoding: utf8mb4

    mysql_users:                        # Define which users to create
      - name: appuser
        password: "{{ vault_appuser_password }}"  # Use Ansible Vault for secrets!
        priv: "appdb.*:ALL"
        host: "192.168.1.%"             # Allow connections from the 192.168.1.x subnet
      - name: readonly
        password: "{{ vault_readonly_password }}"
        priv: "appdb.*:SELECT"          # Read-only user
        host: localhost

  roles:
    - role: base
    - role: mysql
```

---

## 16. Applying a MySQL Role to the DB Servers

The full flow — from inventory to deployed database:

```ini
# File: inventory.ini
[webservers]
web01 ansible_host=192.168.1.10
web02 ansible_host=192.168.1.11

[dbservers]
db01 ansible_host=192.168.1.20
db02 ansible_host=192.168.1.21
```

```yaml
# File: group_vars/dbservers.yml
# Variables applied to ALL db servers
---
mysql_bind_address: "0.0.0.0"           # DB servers need to accept remote connections
mysql_max_connections: 200
mysql_innodb_buffer_pool_size: "512M"
```

```yaml
# File: host_vars/db01.yml
# Variables only for db01 (primary)
---
mysql_server_id: 1                       # Used for replication — must be unique
mysql_role: primary                      # Custom variable for this host's role
```

```yaml
# File: host_vars/db02.yml
# Variables only for db02 (replica)
---
mysql_server_id: 2
mysql_role: replica
mysql_replication_primary: 192.168.1.20  # Point replica to the primary
```

```yaml
# File: site.yml — the master playbook
---
- import_playbook: webservers.yml       # Setup web servers
- import_playbook: dbservers.yml        # Setup database servers
```

Run everything:

```bash
# Deploy the full infrastructure
ansible-playbook -i inventory.ini site.yml

# Only deploy to db servers
ansible-playbook -i inventory.ini site.yml -l dbservers

# Dry run — see what would change without doing it
ansible-playbook -i inventory.ini site.yml --check
```

---

## 17. Variable Precedence

When the same variable is defined in multiple places, which one wins?

Here is the full precedence list, from **lowest to highest** (higher = wins):

```
1.  Role defaults          (roles/x/defaults/main.yml)     ← easiest to override
2.  Inventory group_vars   (group_vars/all.yml)
3.  Inventory group_vars   (group_vars/<group>.yml)
4.  Inventory host_vars    (host_vars/<host>.yml)
5.  Playbook group_vars    (group_vars/*.yml in playbook dir)
6.  Playbook host_vars     (host_vars/*.yml in playbook dir)
7.  Host facts             (gathered automatically)
8.  Play vars:             (vars: block inside the play)
9.  Role vars              (roles/x/vars/main.yml)
10. Task vars:             (vars: inside a task)
11. Extra vars  -e         (ansible-playbook -e "key=value")   ← always wins
```

**In plain English:**

```
defaults < group_vars < host_vars < play vars < role vars < -e flag
 (easy to override)                                   (hard to override)
```

**Practical example:**

```yaml
# defaults/main.yml says:
nginx_port: 80

# group_vars/webservers.yml says:
nginx_port: 8080           # This overrides the default

# host_vars/web01.yml says:
nginx_port: 9090           # This overrides the group var

# -e "nginx_port=443" on the command line overrides EVERYTHING
```

---

## 18. Best Practices for Variable Usage

### ✅ DO: Use `defaults/` for user-configurable values

```yaml
# roles/nginx/defaults/main.yml
nginx_port: 80              # Users should be able to override this
nginx_root: /var/www/html
```

### ✅ DO: Use `vars/` for internal role values

```yaml
# roles/nginx/vars/main.yml
nginx_package: nginx        # Users shouldn't need to change this
nginx_config_dir: /etc/nginx
```

### ✅ DO: Use `group_vars/` and `host_vars/` for environment differences

```
group_vars/
  production.yml    ← production settings
  staging.yml       ← staging settings
host_vars/
  db01.yml          ← db01-specific settings
```

### ✅ DO: Use Ansible Vault for secrets

```bash
# Encrypt a file containing passwords
ansible-vault encrypt group_vars/production/vault.yml

# Reference encrypted variables in a normal vars file (best practice)
```

```yaml
# group_vars/production/vars.yml — NOT encrypted, references vault vars
mysql_root_password: "{{ vault_mysql_root_password }}"    # Points to vault

# group_vars/production/vault.yml — ENCRYPTED with ansible-vault
vault_mysql_root_password: "superSecretPassword123!"
```

### ✅ DO: Use descriptive, namespaced variable names

```yaml
# ✅ Good: namespaced with role name — clear and avoids collisions
nginx_port: 80
mysql_max_connections: 150
app_log_level: info

# ❌ Bad: generic names that clash with other roles
port: 80
max_connections: 150
log_level: info
```

### ✅ DO: Document your variables

```yaml
# File: roles/nginx/defaults/main.yml
---

# Port Nginx listens on. Change to 8080 for non-privileged ports.
nginx_port: 80

# Server name (domain). Set to your domain in production.
nginx_server_name: localhost

# Path to serve files from.
nginx_root: /var/www/html

# Enable SSL. Requires nginx_ssl_cert and nginx_ssl_key to be set.
nginx_ssl_enabled: false
```

### ❌ DON'T: Put secrets in plain text

```yaml
# ❌ NEVER do this — secrets in git = security breach
mysql_root_password: "MySecret123!"

# ✅ Use Ansible Vault or an external secrets manager
mysql_root_password: "{{ vault_mysql_root_password }}"
```

### ❌ DON'T: Use undefined variables without a default filter

```jinja2
{# ❌ If nginx_timeout is not defined, this will CRASH #}
timeout {{ nginx_timeout }};

{# ✅ Provide a fallback with the default filter #}
timeout {{ nginx_timeout | default(60) }};
```

### ❌ DON'T: Define the same variable in both `defaults/` and `vars/`

```yaml
# ❌ Confusing — which one wins? (vars/ does, but it's misleading)
# defaults/main.yml: nginx_port: 80
# vars/main.yml:     nginx_port: 8080

# ✅ Pick ONE place per variable — defaults/ OR vars/, not both
```

---

## Summary

| Concept | What It Is | Key Takeaway |
|---|---|---|
| **Static content explosion** | Config files multiplying per environment | Solve it with variables |
| **Code vs data** | Logic in tasks, values in vars | Never hard-code |
| **Jinja2** | Template engine for filling in variables | `{{ var }}`, `{% if %}`, `{% for %}` |
| **`template` module** | Sends filled-in config files to servers | Better than `copy` for dynamic files |
| **Facts** | Auto-discovered server info | `ansible_os_family`, `ansible_hostname`... |
| **`defaults/main.yml`** | Easy-to-override role defaults | Use for user-facing variables |
| **`vars/main.yml`** | Fixed internal role values | Use for internal role mechanics |
| **`group_vars/`** | Variables per server group | Perfect for environment differences |
| **`host_vars/`** | Variables per individual server | Perfect for host-specific overrides |
| **Variable precedence** | Which definition wins | `-e` flag beats everything |
| **Ansible Vault** | Encrypts secrets in your repo | Always use for passwords/tokens |
