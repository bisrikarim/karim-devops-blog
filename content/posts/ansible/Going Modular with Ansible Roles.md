---
title: "Going Modular with Ansible Roles"
date: 2026-05-05
draft: false
tags: ["ansible", "roles", "modular", "nginx", "handlers", "devops", "infrastructure-as-code", "best-practices"]
description: "Learn how to organize Ansible code into reusable roles — directory structure, site-wide playbooks, parameterization, base roles, Nginx role, dependencies, file management, and handlers."
showToc: true
tocOpen: true
comments: true
---

In previous , we put everything in a single playbook file.  
That works for small things — but imagine managing 50 servers with 200 tasks all in one file. 😱

**Roles** solve this: they let you **organize your Ansible code into neat, reusable packages**.

Think of a role like an **IKEA flat-pack**: everything for one piece of furniture is bundled together, neatly organized, and you can use the same pack in any room.

---

## 1. Understanding Roles

A **role** groups together all the things needed to accomplish one specific goal:
- The tasks to run
- The variables to use
- The files to copy
- The templates to fill in
- The handlers to trigger

**Without roles (messy):**
```
site.yml         ← 400 lines, everything mixed together
```

**With roles (clean):**
```
site.yml         ← short, just calls the roles
roles/
  base/          ← handles common server setup
  nginx/         ← handles Nginx installation & config
  mysql/         ← handles MySQL setup
```

Each role is **self-contained** — it can be reused across projects, shared on Ansible Galaxy, or handed to another team member without confusion.

---

## 2. Naming Roles

A good role name is:
- **Lowercase** only
- Uses **hyphens or underscores** (no spaces)
- **Describes what it does**, not what tech it uses (when possible)

```
# ✅ Good role names
base
nginx
mysql
deploy-app
certificate-manager
node-exporter

# ❌ Bad role names
MyRole            # uppercase
do-stuff          # too vague
nginx-install-and-configure-for-ubuntu  # too long
```

---

## 3. The Directory Layout for Roles

Ansible expects a **specific folder structure** inside each role.  
You don't need all folders — only create the ones you need.

```
roles/
└── nginx/                    # The role name
    ├── tasks/
    │   └── main.yml          # ← The main list of tasks for this role
    ├── handlers/
    │   └── main.yml          # ← Handlers (triggered by tasks, e.g. restart nginx)
    ├── templates/
    │   └── nginx.conf.j2     # ← Jinja2 templates (dynamic config files)
    ├── files/
    │   └── index.html        # ← Static files to copy as-is
    ├── vars/
    │   └── main.yml          # ← Variables (high priority, hard to override)
    ├── defaults/
    │   └── main.yml          # ← Default variables (low priority, easy to override)
    ├── meta/
    │   └── main.yml          # ← Role metadata and dependencies
    └── README.md             # ← Documentation (optional but great habit)
```

**What each folder does:**

| Folder | Purpose |
|---|---|
| `tasks/` | The steps to execute (required) |
| `handlers/` | Actions triggered by tasks (e.g. restart a service) |
| `templates/` | Config files with variables that get filled in at runtime |
| `files/` | Static files copied directly to the server |
| `vars/` | Variables that rarely change (hard-coded values) |
| `defaults/` | Default variable values — users can override these |
| `meta/` | Role dependencies and Ansible Galaxy metadata |

---

## 4. Creating a Site-Wide Playbook, Nesting, and Include Statements

A **site-wide playbook** (`site.yml`) is the **master playbook** — the one you run that orchestrates everything.

It's short and clean because it just calls other playbooks or roles.

### Using `import_playbook` to include other playbooks

```yaml
# File: site.yml
# The master playbook — it just calls the others
---

- import_playbook: base.yml       # First, set up all servers with base config
- import_playbook: webservers.yml # Then, configure the web servers
- import_playbook: dbservers.yml  # Then, configure the database servers
```

### Using `include_tasks` inside tasks

```yaml
# File: roles/nginx/tasks/main.yml
---

- name: Include installation tasks
  include_tasks: install.yml      # Pulls in tasks from another file in the same folder

- name: Include configuration tasks
  include_tasks: configure.yml

- name: Include hardening tasks
  include_tasks: harden.yml
  when: security_hardening | bool  # Only include this if the variable is true
```

**`import_playbook` vs `include_tasks` — What's the difference?**

| | `import_*` (static) | `include_*` (dynamic) |
|---|---|---|
| When resolved | Before playbook runs | During playbook run |
| Supports `when:`? | ❌ No | ✅ Yes |
| Shows in `--list-tasks` | ✅ Yes | ❌ No |
| Best for | Splitting large playbooks | Conditional includes |

---

## 5. Creating the www Playbook

The `webservers.yml` (or `www.yml`) playbook targets only your web servers.

```yaml
# File: webservers.yml
# Playbook for configuring all web servers
---

- name: Configure Web Servers
  hosts: webservers               # Only run on hosts in the "webservers" group
  become: yes                     # Use sudo

  roles:                          # Apply these roles in order:
    - base                        # 1. Common server setup (updates, users, firewall)
    - nginx                       # 2. Install and configure Nginx
```

**The magic of this:** If you have 10 web servers, this runs everything on all 10 in one command.

---

## 6. The Default and Custom Role Paths

Ansible looks for roles in specific places. You can configure where.

### Default role path

```
# Ansible looks here by default:
/etc/ansible/roles/     ← system-wide roles (for all projects)
./roles/                ← roles in your current project folder (most common)
~/.ansible/roles/       ← user-level roles
```

### Setting a custom path in `ansible.cfg`

```ini
# File: ansible.cfg

[defaults]
# Tell Ansible where to find roles
# Ansible searches these paths in order, left to right
roles_path = ./roles:/etc/ansible/roles:~/.ansible/roles
#             ↑ project   ↑ system-wide    ↑ user-level
```

### Installing roles from Ansible Galaxy

```bash
# Ansible Galaxy is like npm/pip but for Ansible roles

# Install a role from Galaxy into your project's roles/ folder
ansible-galaxy install geerlingguy.nginx --roles-path ./roles

# Or define requirements.yml and install all at once
ansible-galaxy install -r requirements.yml
```

```yaml
# File: requirements.yml
---
roles:
  - name: geerlingguy.nginx        # Role name on Galaxy
    version: "3.2.0"               # Pin to a specific version (safer!)

  - name: geerlingguy.mysql
    version: "4.0.0"
```

---

## 7. Parameterizing the Roles

**Parameterization** means making your roles flexible with variables instead of hard-coded values.

Instead of:
```yaml
# ❌ Hard-coded — can't reuse for different setups
- name: Install nginx
  apt:
    name: nginx
  # Port is always 80, package always nginx... what if I need port 8080?
```

Use variables:
```yaml
# ✅ Parameterized — flexible and reusable
- name: Install web server
  apt:
    name: "{{ web_server_package }}"   # Variable — set it differently per environment
```

### Where to define variables (priority order, lowest → highest)

```
defaults/main.yml     ← lowest priority (easy to override, good for defaults)
vars/main.yml         ← higher priority (use for "must be this" values)
inventory vars        ← set per host or group in inventory
playbook vars:        ← set directly in the playbook
-e on command line    ← highest priority (overrides everything)
```

### Example: Parameterized role defaults

```yaml
# File: roles/nginx/defaults/main.yml
# Default values — users can override all of these
---

nginx_port: 80                        # Default HTTP port
nginx_worker_processes: auto          # Let nginx decide based on CPU count
nginx_worker_connections: 1024        # Max connections per worker
nginx_server_name: localhost          # Default server name
nginx_root: /var/www/html             # Default web root directory
nginx_index: "index.html index.htm"   # Default index files
nginx_log_dir: /var/log/nginx         # Where to write logs
```

```yaml
# File: roles/nginx/vars/main.yml
# These values are more "fixed" — override only if you know what you're doing
---

nginx_package: nginx                  # Package name (nginx on Debian, nginx on RHEL)
nginx_service: nginx                  # Service name
nginx_config_dir: /etc/nginx          # Main config directory
nginx_sites_dir: /etc/nginx/sites-available  # Where to put virtual host configs
```

### Overriding defaults in your playbook

```yaml
# File: webservers.yml
---

- name: Configure Web Servers
  hosts: webservers
  become: yes

  roles:
    - role: nginx                    # Use the nginx role...
      vars:                          # ...but override some defaults:
        nginx_port: 8080             # Run on port 8080 instead of 80
        nginx_server_name: myapp.com # Use this domain name
        nginx_root: /var/www/myapp   # Custom web root
```

---

## 8. Creating a Base Role

The **base role** is applied to **every single server** — it's your common baseline.

Typical things a base role handles:
- System updates
- Creating common users and SSH keys
- Setting timezone and hostname
- Installing essential tools (`vim`, `curl`, `htop`)
- Basic firewall rules
- Disabling insecure defaults

### Create the base role structure

```bash
# Ansible can generate the folder structure for you
ansible-galaxy init roles/base
```

This creates:
```
roles/base/
├── tasks/main.yml
├── handlers/main.yml
├── templates/
├── files/
├── vars/main.yml
├── defaults/main.yml
├── meta/main.yml
└── README.md
```

---

## 9. Refactoring Our Code – Creating a Base Role

Let's move common tasks from our old flat playbook into a proper base role.

### Before (everything in one playbook — messy)

```yaml
# Old site.yml — everything crammed together
---
- hosts: all
  become: yes
  tasks:
    - apt: update_cache=yes          # Common setup mixed with app-specific stuff
    - apt: name=vim state=present
    - apt: name=curl state=present
    - user: name=deploy shell=/bin/bash
    - apt: name=nginx state=present  # App stuff mixed in!
    - service: name=nginx state=started
```

### After (clean, modular)

```yaml
# File: roles/base/defaults/main.yml
---
base_packages:          # List of packages every server should have
  - vim
  - curl
  - htop
  - git
  - unzip

base_timezone: UTC      # Default timezone

base_users:             # Users to create on every server
  - name: deploy
    shell: /bin/bash
    groups: sudo
```

```yaml
# File: roles/base/tasks/main.yml
---

# --- Step 1: Update the system
- name: Update apt package cache
  apt:
    update_cache: yes
    cache_valid_time: 3600          # Don't update if cache is fresher than 1 hour

- name: Upgrade all installed packages
  apt:
    upgrade: dist                   # Safe upgrade (won't remove packages)
  register: upgrade_result          # Save the result in a variable

- name: Show upgrade result
  debug:
    msg: "Packages upgraded: {{ upgrade_result.changed }}"

# --- Step 2: Install base packages
- name: Install essential packages
  apt:
    name: "{{ item }}"              # Loop over the list from defaults/main.yml
    state: present
  loop: "{{ base_packages }}"       # base_packages comes from defaults/main.yml

# --- Step 3: Set timezone
- name: Set system timezone
  timezone:
    name: "{{ base_timezone }}"     # Uses the variable from defaults/main.yml

# --- Step 4: Create deploy users
- name: Create system users
  user:
    name: "{{ item.name }}"         # item = each entry in base_users list
    shell: "{{ item.shell }}"
    groups: "{{ item.groups }}"
    create_home: yes
    state: present
  loop: "{{ base_users }}"

# --- Step 5: Clean up old packages
- name: Remove unused packages (autoremove)
  apt:
    autoremove: yes
```

---

## 10. Creating an Nginx Role

Now let's build a proper, reusable Nginx role.

```yaml
# File: roles/nginx/tasks/main.yml
---

# --- Install Nginx
- name: Install Nginx web server
  apt:
    name: "{{ nginx_package }}"     # nginx_package defined in vars/main.yml
    state: present
    update_cache: yes

# --- Create required directories
- name: Ensure Nginx log directory exists
  file:
    path: "{{ nginx_log_dir }}"     # nginx_log_dir from defaults/main.yml
    state: directory
    owner: www-data                 # www-data is the Nginx user on Debian/Ubuntu
    group: www-data
    mode: '0755'

- name: Ensure web root directory exists
  file:
    path: "{{ nginx_root }}"        # nginx_root from defaults/main.yml
    state: directory
    owner: www-data
    group: www-data
    mode: '0755'

# --- Deploy configuration
- name: Deploy Nginx main config
  template:
    src: nginx.conf.j2              # Template file from roles/nginx/templates/
    dest: "{{ nginx_config_dir }}/nginx.conf"   # Where to put it on the server
    owner: root
    group: root
    mode: '0644'
  notify: Reload Nginx              # ← Trigger a handler when this file changes

# --- Enable and start Nginx
- name: Ensure Nginx is started and enabled on boot
  service:
    name: "{{ nginx_service }}"     # nginx_service from vars/main.yml
    state: started
    enabled: yes
```

### The Nginx config template

```nginx
# File: roles/nginx/templates/nginx.conf.j2
# This is a Jinja2 template — {{ variables }} get replaced at runtime

user www-data;
worker_processes {{ nginx_worker_processes }};   # Variable from defaults
pid /run/nginx.pid;

events {
    worker_connections {{ nginx_worker_connections }};  # Variable from defaults
}

http {
    sendfile on;
    tcp_nopush on;

    # Logging configuration
    access_log {{ nginx_log_dir }}/access.log;   # Variable from defaults
    error_log  {{ nginx_log_dir }}/error.log;

    server {
        listen {{ nginx_port }};                 # Variable from defaults (default: 80)
        server_name {{ nginx_server_name }};     # Variable from defaults

        root {{ nginx_root }};                   # Variable from defaults
        index {{ nginx_index }};                 # Variable from defaults

        location / {
            try_files $uri $uri/ =404;
        }
    }
}
```

---

## 11. Adding Role Dependencies

Sometimes a role **requires another role to run first**.  
You declare this in `meta/main.yml`.

**Example:** The `nginx` role depends on `base` being applied first.

```yaml
# File: roles/nginx/meta/main.yml
---

dependencies:              # Roles that must run BEFORE this role
  - role: base             # Always run "base" before "nginx"

  - role: firewall         # Also run "firewall" role first
    vars:                  # Pass variables to the dependency role
      firewall_allowed_ports:
        - 80
        - 443
```

**With this in place, you only need to call the `nginx` role in your playbook** — Ansible will automatically run `base` and `firewall` first:

```yaml
# webservers.yml — clean and simple
---
- hosts: webservers
  become: yes
  roles:
    - nginx     # Ansible will automatically run base → firewall → nginx
```

---

## 12. Managing Files for Nginx

Roles have two ways to provide files to servers:

### Static files → `files/` folder

Files that are **copied exactly as-is**, no variable substitution.

```yaml
# In tasks/main.yml:
- name: Copy custom error page
  copy:
    src: 404.html                      # Located in roles/nginx/files/404.html
    dest: "{{ nginx_root }}/404.html"  # Destination on the server
    owner: www-data
    group: www-data
    mode: '0644'

- name: Copy favicon
  copy:
    src: favicon.ico                   # roles/nginx/files/favicon.ico
    dest: "{{ nginx_root }}/favicon.ico"
```

```
roles/nginx/files/
├── 404.html          ← Your custom "Not Found" page
├── 50x.html          ← Your custom error page
└── favicon.ico       ← Site favicon
```

### Dynamic templates → `templates/` folder

Files with **Jinja2 variables** that get filled in at runtime.

```jinja2
{# File: roles/nginx/templates/vhost.conf.j2 #}
{# The {# #} syntax is a Jinja2 comment #}

server {
    listen {{ nginx_port }};
    server_name {{ nginx_server_name }};

    {# Conditional: only add SSL if enabled #}
    {% if nginx_ssl_enabled %}
    listen 443 ssl;
    ssl_certificate {{ nginx_ssl_cert }};
    ssl_certificate_key {{ nginx_ssl_key }};
    {% endif %}

    root {{ nginx_root }};

    {# Loop: add multiple location blocks if defined #}
    {% for location in nginx_locations %}
    location {{ location.path }} {
        proxy_pass {{ location.backend }};
    }
    {% endfor %}
}
```

```yaml
# In tasks/main.yml:
- name: Deploy virtual host config
  template:
    src: vhost.conf.j2                         # From roles/nginx/templates/
    dest: /etc/nginx/sites-available/myapp     # On the server
    mode: '0644'
  notify: Reload Nginx                         # Trigger handler on change
```

---

## 13. Automating Events and Actions with Handlers

**Handlers** are special tasks that only run **when notified by another task** — and only **once**, even if notified multiple times.

**The classic use case:** Restart Nginx only when its config file has changed.

Without handlers, you'd restart Nginx every time the playbook runs (even if nothing changed). That causes unnecessary downtime.

With handlers:
- Nginx only restarts if a config file actually changed ✅
- Even if 5 tasks all notify the same handler, it only restarts once ✅

### Defining Handlers

```yaml
# File: roles/nginx/handlers/main.yml
---

# A handler looks exactly like a task — but it only runs when notified
- name: Reload Nginx              # ← This name is used in "notify:" statements
  service:
    name: "{{ nginx_service }}"
    state: reloaded               # "reloaded" = graceful config reload (no downtime)
                                  # Use "restarted" only when you MUST restart

- name: Restart Nginx             # Another handler for full restarts
  service:
    name: "{{ nginx_service }}"
    state: restarted

- name: Restart PHP-FPM           # Handlers for other services can live here too
  service:
    name: php8.1-fpm
    state: restarted
```

### Notifying Handlers from Tasks

```yaml
# File: roles/nginx/tasks/main.yml
---

- name: Deploy Nginx main config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Reload Nginx            # ← If this task makes a change, trigger "Reload Nginx"

- name: Deploy virtual host config
  template:
    src: vhost.conf.j2
    dest: /etc/nginx/sites-available/myapp
  notify: Reload Nginx            # ← Both tasks notify the same handler
                                  # Handler still only runs ONCE at the end

- name: Install PHP-FPM
  apt:
    name: php8.1-fpm
    state: present
  notify: Restart PHP-FPM         # Notifies a different handler
```

### Handler Execution Flow

```
TASK: Deploy Nginx main config → CHANGED → queued: "Reload Nginx"
TASK: Deploy virtual host config → CHANGED → queued: "Reload Nginx" (already queued)
TASK: Install PHP-FPM → CHANGED → queued: "Restart PHP-FPM"

All tasks done...

RUNNING HANDLERS:
  → Reload Nginx    (runs ONCE, even though it was notified twice)
  → Restart PHP-FPM
```

### Forcing a Handler to Run Immediately

By default, handlers run at the **end of the play**. Use `flush_handlers` to run them immediately:

```yaml
- name: Deploy new config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Reload Nginx

- name: Force handlers to run now (before continuing)
  meta: flush_handlers           # All pending handlers run here immediately

- name: Test the new config is working
  uri:
    url: http://localhost
    status_code: 200             # Check that Nginx responds with HTTP 200
```

---

## Complete Role Structure — Final Overview

```
my-ansible-project/
├── ansible.cfg                   # Project config (inventory path, ssh user, etc.)
├── inventory.ini                 # List of servers and groups
├── site.yml                      # Master playbook (imports the others)
├── webservers.yml                # Web server playbook
├── dbservers.yml                 # Database server playbook
│
└── roles/
    ├── base/                     # Applied to every server
    │   ├── defaults/main.yml     # ← Default variables (timezone, packages, users)
    │   ├── tasks/main.yml        # ← Update, install base packages, create users
    │   └── meta/main.yml        # ← No dependencies for base
    │
    └── nginx/                    # Applied to web servers
        ├── defaults/main.yml     # ← nginx_port, nginx_root, nginx_server_name...
        ├── vars/main.yml         # ← nginx_package, nginx_config_dir...
        ├── tasks/main.yml        # ← Install, configure, start Nginx
        ├── handlers/main.yml     # ← "Reload Nginx", "Restart Nginx"
        ├── templates/
        │   ├── nginx.conf.j2     # ← Main Nginx config (with variables)
        │   └── vhost.conf.j2     # ← Virtual host config
        ├── files/
        │   ├── 404.html          # ← Static error page
        │   └── favicon.ico       # ← Site favicon
        └── meta/main.yml         # ← Dependencies: [base, firewall]
```

---

## Summary

| Concept | What It Solves | Key File |
|---|---|---|
| **Role** | Organizes code by function | `roles/<name>/` |
| **Directory layout** | Standard structure Ansible expects | `tasks/`, `handlers/`, etc. |
| **site.yml** | One entry point for the whole infra | `import_playbook:` |
| **`defaults/`** | Easy-to-override default values | `defaults/main.yml` |
| **`vars/`** | Fixed internal role values | `vars/main.yml` |
| **Parameterization** | Makes roles reusable | `{{ variable }}` |
| **Base role** | Common baseline for all servers | Applied before any other role |
| **Templates** | Dynamic config files with variables | `.j2` files + Jinja2 |
| **Static files** | Files copied as-is | `files/` folder |
| **Dependencies** | Ensures roles run in right order | `meta/main.yml` |
| **Handlers** | Run tasks only when something changes | `handlers/main.yml` + `notify:` |
