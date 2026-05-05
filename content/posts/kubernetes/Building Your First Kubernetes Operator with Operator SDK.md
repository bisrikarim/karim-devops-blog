---
title: "Building Your First Kubernetes Operator with Operator SDK"
date: 2026-05-05
draft: false
tags: ["kubernetes", "operator-sdk", "go", "devops", "platform-engineering", "crd", "controller"]
description: "A hands-on walkthrough of building a Kubernetes Operator from scratch using Operator SDK — covering CRDs, the reconciliation loop, and real Go controller code."
showToc: true
tocOpen: true
comments: true
---

## What is a Kubernetes Operator?

A **Kubernetes Operator** is an application-specific controller that extends the Kubernetes API to manage complex, stateful applications. It encodes operational knowledge (how to deploy, scale, upgrade, and recover an application) directly into the cluster.

The Operator pattern is built on two pillars:

- **Custom Resource Definitions (CRDs)** — extend the Kubernetes API with your own resource types
- **Controllers** — watch those resources and reconcile the actual cluster state toward the desired state

---

## Lab Environment

| Tool | Version |
|---|---|
| OS | WSL Ubuntu 24.04 |
| Go | 1.23.x |
| Operator SDK | v1.35.0 |
| controller-tools | v0.16.1 |
| Cluster | kind |

> ⚠️ **Important:** Operator SDK v1.35.0 ships with `controller-tools v0.13.0` which is incompatible with Go 1.21+. You must upgrade `controller-tools` to `v0.16.1` in the `Makefile` (see [Fix: controller-tools version](#fix-controller-tools-version)).

---

## Prerequisites

### Install Go

```bash
wget https://go.dev/dl/go1.22.3.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.3.linux-amd64.tar.gz

# Add Go binaries to your shell PATH
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc

go version
```

### Install kind (Kubernetes IN Docker)

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x kind && sudo mv kind /usr/local/bin/

# Spin up a local cluster
kind create cluster --name operator-lab

kubectl cluster-info --context kind-operator-lab
```

### Install Operator SDK CLI

```bash
export ARCH=amd64
export OS=linux
export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/download/v1.35.0

curl -LO ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
chmod +x operator-sdk_${OS}_${ARCH}
sudo mv operator-sdk_${OS}_${ARCH} /usr/local/bin/operator-sdk

operator-sdk version
```

---

## Step 1 — Scaffold the Project

```bash
mkdir ~/operator-lab && cd ~/operator-lab

# Initialize the Go module and project structure
# --domain: the API group domain (resources will be <group>.<domain>)
# --repo:   the Go module path
operator-sdk init \
  --domain=lab.local \
  --repo=github.com/karim/memcached-operator
```

### Fix: controller-tools version

Before creating the API, patch the `Makefile` to use a Go 1.23-compatible version of `controller-tools`:

```bash
# Replace the bundled v0.13.0 (incompatible with Go 1.21+) with v0.16.1
sed -i 's/CONTROLLER_TOOLS_VERSION ?= v0.13.0/CONTROLLER_TOOLS_VERSION ?= v0.16.1/' Makefile

# Also set GOTOOLCHAIN to prevent Go from trying to download a different toolchain
export GOTOOLCHAIN=local
```

---

## Step 2 — Create the API (CRD + Controller)

```bash
# Generate:
#   - api/v1alpha1/memcached_types.go  → the CRD struct definition
#   - internal/controller/memcached_controller.go → the reconciliation logic
operator-sdk create api \
  --group=cache \
  --version=v1alpha1 \
  --kind=Memcached \
  --resource \
  --controller
```

The generated project structure:

```
operator-lab/
├── api/
│   └── v1alpha1/
│       └── memcached_types.go          # CRD: Spec and Status structs
├── internal/
│   └── controller/
│       └── memcached_controller.go     # Controller: reconciliation loop
├── config/                             # Kustomize manifests (RBAC, CRD, etc.)
├── cmd/
│   └── main.go                         # Entrypoint: registers the controller
└── Makefile                            # Build, generate, deploy targets
```

---

## Step 3 — Define the Custom Resource (CRD)

Edit `api/v1alpha1/memcached_types.go` to replace the placeholder `Foo` field with a meaningful `Size` field:

```bash
sed -i 's/Foo string `json:"foo,omitempty"`/Size int32 `json:"size"`/' \
  api/v1alpha1/memcached_types.go
```

The resulting types file:

```go
package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

// MemcachedSpec defines the DESIRED state of a Memcached instance.
// This is what the user declares in their YAML manifest.
type MemcachedSpec struct {
    // Size is the number of Memcached pod replicas to run.
    // The controller will always reconcile the actual replica count to match this value.
    Size int32 `json:"size"`
}

// MemcachedStatus defines the OBSERVED state of a Memcached instance.
// This is updated by the controller to reflect what is actually running.
type MemcachedStatus struct {
    // You can add fields here later, e.g. Conditions, Nodes, Phase, etc.
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

// Memcached is the Schema for the memcacheds API.
// It represents a single instance of a Memcached deployment managed by the operator.
type Memcached struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   MemcachedSpec   `json:"spec,omitempty"`
    Status MemcachedStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// MemcachedList contains a list of Memcached resources.
type MemcachedList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    Items           []Memcached `json:"items"`
}

func init() {
    // Register the types with the global scheme so the controller can recognize them
    SchemeBuilder.Register(&Memcached{}, &MemcachedList{})
}
```

Regenerate the CRD YAML and DeepCopy methods:

```bash
make generate   # Regenerates DeepCopyObject methods (required by the k8s runtime)
make manifests  # Regenerates the CRD YAML in config/crd/bases/
```

Install the CRD into the cluster:

```bash
make install
# Output: customresourcedefinition.apiextensions.k8s.io/memcacheds.cache.lab.local created
```

---

## Step 4 — Implement the Controller

This is the heart of the Operator. Replace `internal/controller/memcached_controller.go` with the following fully commented implementation:

```go
package controller

import (
    "context"

    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/api/errors"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/types"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/log"

    cachev1alpha1 "github.com/karim/memcached-operator/api/v1alpha1"
)

// MemcachedReconciler holds the controller's dependencies.
// It embeds client.Client to interact with the Kubernetes API,
// and Scheme to handle type registration and serialization.
type MemcachedReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

// RBAC markers — controller-gen reads these annotations and generates the
// necessary ClusterRole rules so the operator has the right permissions.
//
// +kubebuilder:rbac:groups=cache.lab.local,resources=memcacheds,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=cache.lab.local,resources=memcacheds/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=cache.lab.local,resources=memcacheds/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete

// Reconcile is the core reconciliation loop.
// It is called by the controller-runtime whenever:
//   - A Memcached CR is created, updated, or deleted
//   - A Deployment owned by a Memcached CR changes
//
// Its job: compare the desired state (CR spec) with the actual state (cluster),
// and take whatever action is needed to make them match.
func (r *MemcachedReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // --- Step 1: Fetch the Memcached CR that triggered this reconciliation ---
    memcached := &cachev1alpha1.Memcached{}
    if err := r.Get(ctx, req.NamespacedName, memcached); err != nil {
        if errors.IsNotFound(err) {
            // The CR was deleted before we could process it — nothing to do.
            // Owned resources (Deployments) will be garbage-collected automatically
            // via OwnerReferences set by SetControllerReference().
            log.Info("Memcached resource not found. Ignoring since object must be deleted")
            return ctrl.Result{}, nil
        }
        // Any other error fetching the CR should be retried
        log.Error(err, "Failed to get Memcached")
        return ctrl.Result{}, err
    }

    // --- Step 2: Check if a Deployment already exists for this CR ---
    found := &appsv1.Deployment{}
    err := r.Get(ctx, types.NamespacedName{
        Name:      memcached.Name,
        Namespace: memcached.Namespace,
    }, found)

    if err != nil && errors.IsNotFound(err) {
        // --- Step 3: Deployment does not exist — create it ---
        dep := r.deploymentForMemcached(memcached)
        log.Info("Creating Deployment", "Namespace", dep.Namespace, "Name", dep.Name)
        if err := r.Create(ctx, dep); err != nil {
            log.Error(err, "Failed to create Deployment")
            return ctrl.Result{}, err
        }
        // Requeue so we immediately reconcile the newly created Deployment
        return ctrl.Result{Requeue: true}, nil
    } else if err != nil {
        log.Error(err, "Failed to get Deployment")
        return ctrl.Result{}, err
    }

    // --- Step 4: Deployment exists — reconcile replica count ---
    // If the user changed spec.size, the controller adjusts the Deployment replicas.
    size := memcached.Spec.Size
    if *found.Spec.Replicas != size {
        found.Spec.Replicas = &size
        if err := r.Update(ctx, found); err != nil {
            log.Error(err, "Failed to update Deployment replicas")
            return ctrl.Result{}, err
        }
        log.Info("Updated Deployment replicas", "Replicas", size)
    }

    // No changes needed — stop reconciling until the next event
    return ctrl.Result{}, nil
}

// deploymentForMemcached builds the Deployment object that the operator will manage.
// It uses the Memcached CR's spec to configure the number of replicas and the container image.
func (r *MemcachedReconciler) deploymentForMemcached(m *cachev1alpha1.Memcached) *appsv1.Deployment {
    // Labels applied to the Deployment and its Pods
    labels := map[string]string{"app": m.Name}
    replicas := m.Spec.Size

    dep := &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      m.Name,
            Namespace: m.Namespace,
        },
        Spec: appsv1.DeploymentSpec{
            Replicas: &replicas,
            Selector: &metav1.LabelSelector{
                MatchLabels: labels, // Must match the Pod template labels
            },
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{Labels: labels},
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{{
                        Name:  "memcached",
                        Image: "memcached:alpine", // Lightweight official Memcached image
                        Ports: []corev1.ContainerPort{{
                            ContainerPort: 11211, // Default Memcached port
                            Name:          "memcached",
                        }},
                    }},
                },
            },
        },
    }

    // SetControllerReference makes the Memcached CR the owner of this Deployment.
    // When the CR is deleted, Kubernetes will automatically garbage-collect the Deployment.
    ctrl.SetControllerReference(m, dep, r.Scheme)
    return dep
}

// SetupWithManager registers the controller with the Manager.
// For(&cachev1alpha1.Memcached{}) — watch Memcached CRs
// Owns(&appsv1.Deployment{})     — also watch Deployments owned by a Memcached CR
//                                  (so if someone manually deletes the Deployment, we recreate it)
func (r *MemcachedReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&cachev1alpha1.Memcached{}).
        Owns(&appsv1.Deployment{}).
        Complete(r)
}
```

---

## Step 5 — Run and Test

### Start the controller (Terminal 1)

```bash
make run
```

Expected output:

```
INFO    setup   starting manager
INFO    Starting EventSource  {"controller": "memcached", "source": "kind source: *v1alpha1.Memcached"}
INFO    Starting EventSource  {"controller": "memcached", "source": "kind source: *v1.Deployment"}
INFO    Starting workers      {"controller": "memcached", "worker count": 1}
```

### Create a Memcached instance (Terminal 2)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cache.lab.local/v1alpha1
kind: Memcached
metadata:
  name: memcached-sample
spec:
  size: 3     # We want 3 replicas
EOF
```

The controller logs (Terminal 1):

```
INFO    Creating Deployment   {"Namespace": "default", "Name": "memcached-sample"}
```

Verify the pods:

```bash
kubectl get pods
# NAME                                READY   STATUS    RESTARTS   AGE
# memcached-sample-8678997c68-7ps72   1/1     Running   0          10s
# memcached-sample-8678997c68-txmmh   1/1     Running   0          10s
# memcached-sample-8678997c68-whtpk   1/1     Running   0          10s
```

### Test reconciliation — scale down

```bash
# Patch the CR to request only 1 replica
kubectl patch memcached memcached-sample --type=merge -p '{"spec":{"size":1}}'
```

```bash
kubectl get pods
# NAME                                READY   STATUS    RESTARTS   AGE
# memcached-sample-8678997c68-txmmh   1/1     Running   0          90s
```

The controller detected the spec change and automatically scaled the Deployment down from 3 to 1. ✅

---

## How the Reconciliation Loop Works

```
User applies CR (size: 3)
        │
        ▼
  Controller triggered
        │
        ├─ Fetch Memcached CR  ──► Not found? → skip (deleted)
        │
        ├─ Get Deployment      ──► Not found? → Create it  ──► Requeue
        │
        └─ Compare replicas
              │
              ├─ Mismatch? → Update Deployment replicas
              │
              └─ Match?   → Nothing to do, stop
```

---

## Key Concepts Summary

| Concept | Role |
|---|---|
| **CRD** | Extends the Kubernetes API with a new resource type (`Memcached`) |
| **Spec** | The desired state declared by the user |
| **Status** | The observed state updated by the controller |
| **Reconcile loop** | Continuously drives actual state → desired state |
| **OwnerReference** | Links the Deployment to the CR for automatic garbage collection |
| **Owns()** | Makes the controller also react to changes in its owned Deployments |
| **RBAC markers** | `+kubebuilder:rbac` annotations auto-generate the operator's permissions |

---

## What's Next?

- **Finalizers** — run custom cleanup logic before a CR is deleted
- **Status Conditions** — expose rich operator state via `metav1.Condition`
- **Webhooks** — validate or mutate CRs at admission time
- **Deploy in-cluster** — build a Docker image and deploy the operator as a Pod
