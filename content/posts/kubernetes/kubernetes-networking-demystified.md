---
title: "Kubernetes Networking Demystified: From Pod-to-Pod to Ingress"
date: 2024-03-15
draft: false
tags: ["kubernetes", "networking", "cni", "devops", "platform-engineering"]
description: "A practical breakdown of how Kubernetes networking works — CNI plugins, kube-proxy, DNS, and Ingress — with real configuration examples."
showToc: true
tocOpen: true
comments: true
---

## Context

Kubernetes networking is one of those topics that feels abstract until something breaks in production. The mental model that most engineers develop — _pods get IPs, services load-balance traffic, Ingress handles external access_ — is a simplification that collapses under real-world scenarios.

This post documents what I've learned through managing Kubernetes clusters at scale: 5+ clusters, hundreds of pods, multi-namespace service meshes, and a few memorable network partitioning incidents.

Goal: give you a complete mental model, not a tutorial.

---

## Problem

Three concrete problems that motivated this write-up:

1. **Service-to-service latency spikes** — random 200–400ms spikes between microservices in the same namespace, appearing only under load. Root cause: kube-proxy iptables chain traversal at scale.

2. **Cross-namespace DNS resolution failures** — a new team's services couldn't resolve names from a different namespace despite correct NetworkPolicy rules. Root cause: misunderstanding of DNS resolution scope.

3. **Ingress 502s after node scale-out** — Traefik returning 502s for ~30 seconds after autoscaler added nodes. Root cause: endpoint propagation lag in kube-proxy.

Each of these required understanding networking at a different layer. Let's go through them.

---

## Solution

The key insight: Kubernetes networking is a **layered model**. Each layer has its own failure modes.

```
┌─────────────────────────────────────┐
│           External Traffic          │
├─────────────────────────────────────┤
│    Ingress Controller (L7 routing)  │
├─────────────────────────────────────┤
│    Service (L4 load balancing)      │
├─────────────────────────────────────┤
│    Pod Network (CNI)                │
├─────────────────────────────────────┤
│    Node Network (underlying infra)  │
└─────────────────────────────────────┘
```

Understanding which layer owns which problem is what separates fast debugging from guesswork.

---

## Implementation

### Layer 1 — Pod Network (CNI)

Every pod gets a unique IP from the cluster CIDR. Pods on the same node communicate via a virtual bridge. Pods on different nodes communicate via the CNI plugin.

We use **Calico** in production. Here's a minimal CNI config:

```yaml
# calico-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: calico-config
  namespace: kube-system
data:
  calico_backend: "bird"
  cluster_type: "kubespray,bgp"
  cni_network_config: |-
    {
      "name": "k8s-pod-network",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "calico",
          "log_level": "info",
          "ipam": {
            "type": "calico-ipam"
          }
        }
      ]
    }
```

Key point: **the CNI plugin is responsible for routing between nodes**. Calico uses BGP. Flannel uses VXLAN. Your choice here affects cross-node latency, MTU, and debug tooling.

### Layer 2 — Services and kube-proxy

`Service` objects are virtual — they exist only as iptables (or IPVS) rules on every node. When you hit a ClusterIP, the kernel intercepts the packet and NATs it to a real pod IP.

This is the source of Problem #1 above. At scale, iptables rule traversal becomes O(n) — every connection checks all rules sequentially.

**Fix: switch to IPVS mode**

```yaml
# kube-proxy configmap
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-proxy
  namespace: kube-system
data:
  config.conf: |
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
    mode: "ipvs"                    # was "iptables"
    ipvs:
      scheduler: "rr"               # round-robin
      syncPeriod: 30s
      minSyncPeriod: 5s
```

After switching to IPVS, our latency spikes disappeared. IPVS uses a hash table — O(1) lookup regardless of service count.

**Verify it works:**

```bash
# Check IPVS rules
kubectl exec -n kube-system ds/kube-proxy -- ipvsadm -Ln

# Confirm mode
kubectl get configmap kube-proxy -n kube-system -o yaml | grep mode
```

### Layer 3 — DNS Resolution

CoreDNS handles all in-cluster DNS. The FQDN pattern is:

```
<service>.<namespace>.svc.cluster.local
```

Within the same namespace, you can use just `<service>`. Across namespaces, you need `<service>.<namespace>` or the full FQDN.

Problem #2 was caused by a team using short names for cross-namespace services. Their pods had `ndots: 5` in resolv.conf (the default), so the resolver tried 5 search domain permutations before attempting the absolute name — and none matched.

**Diagnosis:**

```bash
# Check DNS resolution from inside a pod
kubectl exec -it <pod> -- nslookup myservice.other-namespace

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

# Inspect pod DNS config
kubectl exec -it <pod> -- cat /etc/resolv.conf
```

**Fix: use FQDN or tune ndots**

```yaml
# Pod spec DNS config
spec:
  dnsConfig:
    options:
      - name: ndots
        value: "2"    # reduces unnecessary search domain queries
```

Or simply use the full FQDN in your service client config: `myservice.other-namespace.svc.cluster.local`.

### Layer 4 — Ingress and Endpoint Propagation

Problem #3 was the most subtle. After a node scale-out, Traefik returned 502s for ~30 seconds. Here's what happens:

1. Autoscaler adds node, pods schedule on it
2. Pod becomes `Running` (kubelet reports ready)
3. Endpoints controller updates the Endpoints object
4. kube-proxy syncs iptables rules (~5s delay)
5. Ingress controller refreshes upstream list (~10–20s depending on poll interval)

The gap between step 2 and step 5 is the window of 502s.

**Fix: tune readiness probe + preStop hook**

```yaml
spec:
  containers:
    - name: app
      readinessProbe:
        httpGet:
          path: /healthz
          port: 8080
        initialDelaySeconds: 5
        periodSeconds: 5
        failureThreshold: 3
      lifecycle:
        preStop:
          exec:
            command: ["sleep", "15"]    # wait for endpoint removal before shutdown
```

The `preStop` sleep ensures pods aren't removed from the load balancer before in-flight requests complete during rollouts.

**For Traefik specifically**, reduce the endpoint refresh interval:

```yaml
# Traefik deployment args
- --providers.kubernetesingress.throttleduration=5s
```

---

## Conclusion

Three production problems, three different network layers:

| Problem | Layer | Root Cause | Fix |
|---|---|---|---|
| Latency spikes | Service | iptables O(n) | Switch to IPVS |
| DNS failures | DNS | Search domain + ndots | Use FQDN or tune ndots |
| Ingress 502s | Ingress | Endpoint propagation lag | preStop hook + probe tuning |

The pattern: **most Kubernetes network issues have a known root cause** if you understand the layer responsible. Build a mental model of the stack, and debugging becomes systematic instead of a guessing game.

### Tools I use for network debugging

```bash
# General connectivity
kubectl exec -it <pod> -- curl -v http://<service>:<port>

# DNS
kubectl exec -it <pod> -- nslookup <service>
kubectl exec -it <pod> -- dig <fqdn>

# Network policy testing
kubectl exec -it <pod> -- nc -zv <target-ip> <port>

# Packet capture (requires privileged pod)
kubectl debug node/<node> -it --image=nicolaka/netshoot

# IPVS rules
kubectl exec -n kube-system ds/kube-proxy -- ipvsadm -Ln

# Endpoint propagation
kubectl get endpoints <service> -w
```

If this was useful, the next post will cover **NetworkPolicy design patterns** — how to go from zero network isolation to least-privilege without breaking your platform.

---

_Tags: kubernetes, networking, CNI, kube-proxy, DNS, Ingress, platform-engineering_
