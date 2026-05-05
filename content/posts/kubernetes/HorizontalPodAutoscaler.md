---
title: "Kubernetes Scaling Demystified: Manual Scaling and HorizontalPodAutoscaler"
date: 2026-05-05
draft: false
tags: ["kubernetes", "scaling", "hpa", "autoscaling", "statefulset", "cka", "devops", "platform-engineering"]
description: "A practical breakdown of Kubernetes scaling — manual scaling for Deployments and StatefulSets, HorizontalPodAutoscaler with CPU and memory metrics, and CKA exam traps."
showToc: true
tocOpen: true
comments: true
---

## 1. Core Concepts

| Scaling type | Mechanism | Kubernetes primitive |
|---|---|---|
| **Vertical** | Increase resources (CPU/RAM) per Pod | VerticalPodAutoscaler (out of CKA scope) |
| **Horizontal** | Increase the number of Pods | `kubectl scale` / HorizontalPodAutoscaler |

---

## 2. Manual Scaling

### 2.1 Scaling a Deployment

```bash
# Increase the number of replicas to 6
kubectl scale deployment app-cache --replicas=6
# → deployment.apps/app-cache scaled

# Watch Pod creation in real time
kubectl get pods -w
# app-cache-5d6748d8b9-6cc4j   0/1   ContainerCreating   0   11s
# app-cache-5d6748d8b9-6z7g5   0/1   ContainerCreating   0   11s
# app-cache-5d6748d8b9-6rmlj   1/1   Running             0   28m
# ...
```

> In production, prefer editing `spec.replicas` in the versioned YAML manifest and then running `kubectl apply`.

### 2.2 Scaling a StatefulSet

A StatefulSet is designed for **stateful** applications (e.g. databases). Each replica has a **unique and persistent identity**.

```yaml
# redis.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
spec:
  selector:
    matchLabels:
      app: redis
  replicas: 1
  serviceName: "redis"
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:6.2.5
        command: ["redis-server", "--appendonly", "yes"]
        ports:
        - containerPort: 6379
          name: web
        volumeMounts:
        - name: redis-vol
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: redis-vol
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

```bash
kubectl apply -f redis.yaml

# Check the StatefulSet (Pods are named sequentially: redis-0, redis-1...)
kubectl get statefulset redis
# NAME    READY   AGE
# redis   1/1     2m10s

kubectl get pods
# NAME      READY   STATUS    RESTARTS   AGE
# redis-0   1/1     Running   0          2m

# Scale to 3 replicas
kubectl scale statefulset redis --replicas=3

kubectl get pods
# NAME      READY   STATUS    RESTARTS   AGE
# redis-0   1/1     Running   0          101m
# redis-1   1/1     Running   0          97m
# redis-2   1/1     Running   0          97m
```

> **Important**: scaling down a StatefulSet requires **all replicas to be healthy**. A stuck Pod can make the application unavailable.

---

## 3. HorizontalPodAutoscaler (HPA)

The HPA **automatically** adjusts the number of replicas based on resource metrics (CPU, memory).

![HPA autoscaling architecture](captures/hpa-architecture.png)

### 3.1 Prerequisites

Three mandatory conditions for the HPA to work:

| Prerequisite | Detail |
|---|---|
| **Metrics Server installed** | Without it, the HPA cannot retrieve metrics |
| **Resource requests defined** | CPU → `requests.cpu` required; Memory → `requests.memory` required |
| **Sufficient cluster resources** | The cluster must be able to schedule new Pods |

> If resource requests are not defined, the `TARGETS` column shows `<unknown>`.

---

### 3.2 Creating an HPA

#### Imperative approach

```bash
# CPU-only HPA
kubectl autoscale deployment app-cache \
  --cpu-percent=80 \
  --min=3 \
  --max=5
# → horizontalpodautoscaler.autoscaling/app-cache autoscaled
```

#### Declarative approach

```yaml
# hpa-cpu.yaml — CPU-only HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-cache
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app-cache         # targeted Deployment
  minReplicas: 3            # minimum number of replicas
  maxReplicas: 5            # maximum number of replicas
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80    # threshold in %
```

#### HPA with CPU + Memory

```yaml
# hpa-cpu-memory.yaml — HPA on both CPU and memory
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-cache
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app-cache
  minReplicas: 3
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: AverageValue
        averageValue: 500Mi       # absolute value (not a percentage)
```

#### Associated resource requests in the Pod template

```yaml
# To be defined in spec.template.spec.containers of the Deployment
resources:
  requests:
    cpu: 250m
    memory: 100Mi
  limits:
    cpu: 500m
    memory: 500Mi
```

---

### 3.3 Listing and inspecting HPAs

```bash
# List HPAs (alias: hpa)
kubectl get hpa
# NAME        REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
# app-cache   Deployment/app-cache    15%/80%         3         5         4          58s

# If resource requests are missing:
# TARGETS → <unknown>/80%

# With CPU + memory:
# TARGETS → 1994752/500Mi, 0%/80%

# Full details (rescaling events included)
kubectl describe hpa app-cache
```

![Horizontal autoscaling diagram by CPU](captures/hpa-cpu-scaling.png)

> `describe` shows **rescaling events**: when the replica count changed and why — very useful for troubleshooting.

---

## 4. Summary: Manual Scaling vs HPA

| Criterion | Manual | HPA |
|---|---|---|
| Trigger | Manual | Automatic based on metrics |
| Reactivity | Limited | Real-time |
| Prerequisites | None | Metrics Server + resource requests |
| Compatible resources | Deployment, StatefulSet | Deployment, ReplicaSet, StatefulSet (not standalone Pods) |
| Recommended usage | Tests, predictable loads | Production, variable loads |

---

## 5. Quick Reference Commands

```bash
# Manual scaling
kubectl scale deployment <name> --replicas=<n>
kubectl scale statefulset <name> --replicas=<n>

# HPA
kubectl autoscale deployment <name> --cpu-percent=<n> --min=<n> --max=<n>
kubectl get hpa
kubectl describe hpa <name>
kubectl delete hpa <name>

# Watch scaling in real time
kubectl get pods -w
```

---

## 6. Exercises

### Exercise 1 — Deployment and manual scaling

**Solution:**

```yaml
# hello-world-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello-world
        image: bmuschko/nodejs-hello-world:1.0.0
```

```bash
# 1. Create the Deployment
kubectl apply -f hello-world-deployment.yaml

# Check 3 replicas
kubectl get deployment hello-world
# → READY 3/3

# 2. Edit replicas: 3 → 8 in hello-world-deployment.yaml
# (edit the file: replace replicas: 3 with replicas: 8)

# Apply the changes
kubectl apply -f hello-world-deployment.yaml

# Check 8 replicas
kubectl get deployment hello-world
# → READY 8/8

kubectl get pods
# → 8 Pods in Running state
```

---

### Exercise 2 — nginx Deployment + HPA on CPU + memory

**Solution:**

```yaml
# nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.23.4
        resources:
          requests:
            cpu: "0.5"          # 500m
            memory: "500Mi"
          limits:
            memory: "500Mi"     # memory limit = memory request
```

```bash
# 1. Create the Deployment
kubectl apply -f nginx-deployment.yaml

kubectl get deployment nginx
# → READY 1/1
```

```yaml
# nginx-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx
  minReplicas: 3
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 75    # 75% CPU
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 60    # 60% memory
```

```bash
# 2. Create the HPA
kubectl apply -f nginx-hpa.yaml

# 3. Inspect the HPA
kubectl get hpa nginx-hpa
# NAME        REFERENCE           TARGETS                    MINPODS   MAXPODS   REPLICAS
# nginx-hpa   Deployment/nginx    <memory>%/60%, <cpu>%/75%  3         8         3

kubectl describe hpa nginx-hpa
# → Conditions, rescaling events, current metrics
```

> **How many replicas?**  
> Without real application load, CPU and memory consumption is very low (below the 75% and 60% thresholds). The HPA will therefore **scale DOWN to the minimum** → **3 replicas** (the `minReplicas` value).

---

## CKA Exam Traps

| Trap | Solution |
|---|---|
| HPA with `TARGETS: <unknown>` | `resource requests` are not defined in the Pod template |
| HPA without Metrics Server | Install the Metrics Server — without it the HPA cannot work |
| HPA on a standalone Pod | **Not possible** — HPA only supports Deployment, ReplicaSet, StatefulSet |
| Scale down StatefulSet with a Pod in error | Scale down is blocked — fix the Pod issue first |
| `averageUtilization` vs `averageValue` | CPU → `Utilization` (%); Memory → `AverageValue` (Mi) or `Utilization` (%) |
| minReplicas not respected | If load is below thresholds, HPA scales down to `minReplicas`, never below |
