---
title: "Kubernetes ConfigMaps & Secrets: Complete Practical Guide"
date: 2026-05-05
draft: false
tags: ["kubernetes", "configmap", "secret", "cka", "devops", "platform-engineering"]
description: "A practical breakdown of how Kubernetes ConfigMaps and Secrets work — creation, consumption as env vars or volumes, key remapping, and CKA exam traps."
showToc: true
tocOpen: true
comments: true
---

## 1. Core Concepts

Kubernetes provides two primitives to centralize configuration:

| Primitive | Data type | Typical usage |
|---|---|---|
| **ConfigMap** | Plain-text | URLs, flags, JSON/YAML files, properties |
| **Secret** | Base64-encoded | Passwords, API keys, SSL certificates, SSH keys |

Both are **decoupled from the Pod lifecycle** — you can update the config without redeploying the Pod.

![Diagram of the two ConfigMap and Secret consumption modes from a Pod](captures/configmap-secret-consumption.png)

> **Important**: Base64 is an **encoding**, not **encryption**. Anyone with access to the Secret can decode its value. For real encryption in production: use **Bitnami Sealed Secrets** or an external secret manager (HashiCorp Vault, AWS Secrets Manager).

---

## 2. ConfigMaps

### 2.1 Creating a ConfigMap

Four possible sources:

| Option | Example | Description |
|---|---|---|
| `--from-literal` | `--from-literal=DB_HOST=mysql` | Key-value pairs on the command line |
| `--from-env-file` | `--from-env-file=config.env` | Env variable file (`KEY=value` per line) |
| `--from-file` | `--from-file=app-config.json` | File with arbitrary content (JSON, XML, YAML…) |
| `--from-file` | `--from-file=config-dir/` | Directory containing multiple files |

> `--from-env-file` expects a `.env`-style variable file.  
> `--from-file` is designed for structured config files (JSON, properties…).

```bash
# From literals
kubectl create configmap db-config \
  --from-literal=DB_HOST=mysql-service \
  --from-literal=DB_USER=backend

# From a JSON file
kubectl create configmap db-config --from-file=db.json

# From a directory
kubectl create configmap db-config --from-file=config-dir/
```

```yaml
# Resulting YAML (from literals)
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
data:                        # no spec section — just data
  DB_HOST: mysql-service
  DB_USER: backend
```

```yaml
# Resulting YAML (from a JSON file)
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
data:
  db.json: |-               # the filename becomes the key
    {
      "db": {
        "host": "mysql-service",
        "user": "backend"
      }
    }
```

---

### 2.2 Consuming a ConfigMap as environment variables

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
spec:
  containers:
  - image: bmuschko/web-app:1.0.1
    name: backend
    envFrom:
    - configMapRef:
        name: db-config     # injects ALL ConfigMap keys as env vars
```

```bash
# Check the injected variables
kubectl exec backend -- env
# → DB_HOST=mysql-service
# → DB_USER=backend
```

---

### 2.3 Mounting a ConfigMap as a volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
spec:
  containers:
  - image: bmuschko/web-app:1.0.1
    name: backend
    volumeMounts:
    - name: db-config-volume
      mountPath: /etc/config    # each key becomes a file in this directory
  volumes:
  - name: db-config-volume
    configMap:
      name: db-config           # references the ConfigMap by name
```

```bash
# Check the mounted content
kubectl exec -it backend -- /bin/sh
# ls -1 /etc/config
# → db.json
# cat /etc/config/db.json
# → { "db": { "host": "mysql-service", "user": "backend" } }
```

---

## 3. Secrets

### 3.1 Secret types

| CLI option | Description | Internal type |
|---|---|---|
| `generic` | From file, directory or literal | `Opaque` |
| `docker-registry` | For pulling images from a private registry | `kubernetes.io/dockercfg` |
| `tls` | TLS certificate | `kubernetes.io/tls` |

Common specialised types:

| Type | Expected keys | Usage |
|---|---|---|
| `kubernetes.io/basic-auth` | `username`, `password` | Basic authentication |
| `kubernetes.io/ssh-auth` | `ssh-privatekey` | Private SSH key |
| `kubernetes.io/tls` | `tls.crt`, `tls.key` | TLS certificate |

---

### 3.2 Creating a Secret

```bash
# From literals (Base64-encoded automatically)
kubectl create secret generic db-creds \
  --from-literal=pwd=s3cre!

# From an SSH file
cp ~/.ssh/id_rsa ssh-privatekey
kubectl create secret generic secret-ssh-auth \
  --from-file=ssh-privatekey \
  --type=kubernetes.io/ssh-auth
```

```yaml
# Resulting YAML — value automatically Base64-encoded
apiVersion: v1
kind: Secret
metadata:
  name: db-creds
type: Opaque
data:
  pwd: czNjcmUh              # Base64 of "s3cre!"
```

#### Manually encoding / decoding

```bash
# Encode to Base64
echo -n 's3cre!' | base64
# → czNjcmUh

# Decode
echo -n 'czNjcmUh' | base64 --decode
# → s3cre!
```

#### Using `stringData` (plain-text in the manifest)

```yaml
# Manifest with stringData — Kubernetes encodes automatically at creation time
apiVersion: v1
kind: Secret
metadata:
  name: db-creds
type: Opaque
stringData:
  pwd: s3cre!               # plain-text in the manifest
```

> The live object (`kubectl get secret db-creds -o yaml`) will always use `data` with the Base64-encoded value, even if you used `stringData` in the manifest.

#### Secret with a specialised type

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-basic-auth
type: kubernetes.io/basic-auth
stringData:
  username: bmuschko        # keys required by the type
  password: secret
```

---

### 3.3 Consuming a Secret as environment variables

```yaml
# Injecting all Secret keys
apiVersion: v1
kind: Pod
metadata:
  name: backend
spec:
  containers:
  - image: bmuschko/web-app:1.0.1
    name: backend
    envFrom:
    - secretRef:
        name: secret-basic-auth    # Kubernetes automatically decodes Base64
```

```bash
kubectl exec backend -- env
# → username=bmuschko
# → password=secret
```

---

### 3.4 Remapping environment variable keys

Useful when Secret keys do not follow env var naming conventions.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
spec:
  containers:
  - image: bmuschko/web-app:1.0.1
    name: backend
    env:
    - name: USER              # new variable name inside the container
      valueFrom:
        secretKeyRef:
          name: secret-basic-auth
          key: username       # source key in the Secret
    - name: PWD
      valueFrom:
        secretKeyRef:
          name: secret-basic-auth
          key: password
```

```bash
kubectl exec backend -- env
# → USER=bmuschko
# → PWD=secret
```

> The same mechanism works for ConfigMaps — use `configMapKeyRef` instead of `secretKeyRef`.

---

### 3.5 Mounting a Secret as a volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
spec:
  containers:
  - image: bmuschko/web-app:1.0.1
    name: backend
    volumeMounts:
    - name: ssh-volume
      mountPath: /var/app
      readOnly: true           # files from a mounted Secret are read-only
  volumes:
  - name: ssh-volume
    secret:
      secretName: secret-ssh-auth    # note: secretName (not name) for Secrets
```

```bash
kubectl exec -it backend -- /bin/sh
# ls -1 /var/app
# → ssh-privatekey
# cat /var/app/ssh-privatekey
# → -----BEGIN RSA PRIVATE KEY-----
# → ...
# → -----END RSA PRIVATE KEY-----
# (content is automatically decoded by Kubernetes)
```

> **Gotcha**: the attribute is `secretName` for Secrets (vs `name` for ConfigMaps).

---

## 4. ConfigMap vs Secret — Comparison Table

| Criterion | ConfigMap | Secret |
|---|---|---|
| Data type | Plain-text | Base64-encoded |
| YAML section | `data` | `data` or `stringData` |
| Usage | Non-sensitive config | Credentials, keys, certificates |
| Reference in `envFrom` | `configMapRef` | `secretRef` |
| Reference in `env.valueFrom` | `configMapKeyRef` | `secretKeyRef` |
| Reference in `volumes` | `configMap.name` | `secret.secretName` |
| Encryption at rest | No (by default) | No (by default) |

---

## 5. Quick Reference Commands

```bash
# ConfigMap
kubectl create configmap <name> --from-literal=KEY=value
kubectl create configmap <name> --from-file=file.json
kubectl create configmap <name> --from-env-file=config.env
kubectl get configmap <name> -o yaml
kubectl describe configmap <name>

# Secret
kubectl create secret generic <name> --from-literal=KEY=value
kubectl create secret generic <name> --from-file=file
kubectl create secret tls <name> --cert=cert.crt --key=cert.key
kubectl get secret <name> -o yaml
kubectl describe secret <name>

# Decode a Secret value
kubectl get secret <name> -o jsonpath='{.data.KEY}' | base64 --decode
```

---

## 6. Exercises

### Exercise 1 — ConfigMap from a YAML file, mounted as a volume

**Solution:**

```bash
# 1. Inspect the source file
# (in the bmuschko/cka-study-guide repo: app-a/ch10/configmap/application.yaml)
cat application.yaml
```

```yaml
# Example content of application.yaml
db:
  host: mysql-service
  port: 3306
app:
  environment: production
  debug: false
```

```bash
# 2. Create the ConfigMap from the file
kubectl create configmap app-config --from-file=application.yaml

# Verify
kubectl get configmap app-config -o yaml
# → data.application.yaml contains the file content
```

```yaml
# 3. Create the Pod that mounts the ConfigMap as a volume
# pod-configmap.yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
spec:
  containers:
  - name: backend
    image: nginx:1.23.4-alpine
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: app-config
```

```bash
kubectl apply -f pod-configmap.yaml

# 4. Inspect the mounted content
kubectl exec -it backend -- /bin/sh
# ls -1 /etc/config
# → application.yaml
# cat /etc/config/application.yaml
# → db:
# →   host: mysql-service
# →   port: 3306
# → ...
```

---

### Exercise 2 — Secret as an environment variable

**Solution:**

```bash
# 1. Create the Secret
kubectl create secret generic db-credentials \
  --from-literal=db-password=passwd

# Verify
kubectl get secret db-credentials -o yaml
# → data.db-password: cGFzc3dk  (Base64 of "passwd")
```

```yaml
# 2. Create the Pod that injects the Secret as an env var
# pod-secret.yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
spec:
  containers:
  - name: backend
    image: nginx:1.23.4-alpine
    env:
    - name: DB_PASSWORD           # variable name inside the container
      valueFrom:
        secretKeyRef:
          name: db-credentials    # Secret name
          key: db-password        # key inside the Secret
```

```bash
kubectl apply -f pod-secret.yaml

# 3. Check the environment variable inside the container
kubectl exec -it backend -- /bin/sh
# env | grep DB_PASSWORD
# → DB_PASSWORD=passwd
# (Kubernetes automatically decodes Base64)
```

---

## CKA Exam Traps

| Trap | Solution |
|---|---|
| Secret = encrypted | **False** — Base64 is an encoding, not encryption |
| `secretName` vs `name` in volumes | Secrets = `secretName`, ConfigMaps = `name` |
| `stringData` vs `data` | `stringData` = plain-text in the manifest, `data` = Base64. The live object always uses `data` |
| Editing a ConfigMap/Secret is enough to reload the Pod | Not always — depends on whether it is mounted as a volume (automatic reload) or env var (requires Pod restart) |
| `--from-env-file` vs `--from-file` | `--from-env-file` = env variable file; `--from-file` = arbitrary file (JSON, XML…) |
