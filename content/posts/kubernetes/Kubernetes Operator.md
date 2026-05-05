---
title: "Building a Kubernetes Operator with Go: A Practical Guide"
date: 2026-05-05
draft: false
tags: ["kubernetes", "operator", "go", "kubebuilder", "controller-runtime", "devops", "platform-engineering"]
description: "A hands-on guide to building a Kubernetes Operator in Go using Kubebuilder — CRD definition, reconcile loop, RBAC, and live testing in WSL."
showToc: true
tocOpen: true
comments: true
---

## What is a Kubernetes Operator?

Think of a Kubernetes Operator as a **robot that watches your cluster and reacts automatically**.

Normally, when you create a `Deployment`, Kubernetes knows what to do.
An Operator lets you **teach Kubernetes new tricks** — you define your own resource type,
and your own logic for what should happen when that resource is created, updated, or deleted.

```
Normal K8s:   you apply a Deployment  →  K8s creates Pods
Your Operator: you apply a Webapp     →  your code creates a Deployment (+ anything else you want)
```

**3 pieces you always need:**

| Piece | What it is | Analogy |
|---|---|---|
| **CRD** (Custom Resource Definition) | The schema / blueprint | A form template |
| **CR** (Custom Resource) | An instance of your CRD | A filled-in form |
| **Controller** | Your Go code that watches CRs | The person who reads the form and acts |

---

## Prerequisites

- WSL with Go installed (≥ 1.23)
- `kubectl` configured and pointing to a running cluster
- Internet access

---

## Step 1 — Install the tools

```bash
# ── Go 1.23+ ────────────────────────────────────────────────────────────────
wget https://go.dev/dl/go1.23.8.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.23.8.linux-amd64.tar.gz

# Add Go to PATH permanently
echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

go version   # → go version go1.23.8 linux/amd64


# ── Kubebuilder (the operator scaffolding tool) ──────────────────────────────
curl -L -o kubebuilder "https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)"
chmod +x kubebuilder
sudo mv kubebuilder /usr/local/bin/

kubebuilder version   # → should print version info


# ── controller-gen (generates CRD manifests from Go code annotations) ────────
go install sigs.k8s.io/controller-tools/cmd/controller-gen@latest
```

> **WSL tip:** if `go` is not found after install, your shell is pointing to the old system Go.
> Fix: `sudo rm /usr/bin/go && hash -r && source ~/.bashrc`

---

## Step 2 — Scaffold the project

```bash
mkdir my-operator && cd my-operator

# Initialize the Go module and the Kubebuilder project
kubebuilder init \
  --domain example.com \           # your API group domain (e.g. apps.example.com)
  --repo github.com/karim/my-operator  # Go module path (doesn't have to be real)

# Create the API: this generates the CRD type + the controller
kubebuilder create api \
  --group apps \          # group name  → apps.example.com
  --version v1alpha1 \    # version     → still experimental, use v1alpha1
  --kind Webapp \         # resource name (PascalCase, singular)
  --resource \            # generate the types file
  --controller            # generate the controller file
```

After this, your project looks like:

```
my-operator/
├── api/
│   └── v1alpha1/
│       ├── webapp_types.go          ← YOU EDIT THIS: define your CR fields
│       └── zz_generated.deepcopy.go ← auto-generated, do not touch
├── internal/
│   └── controller/
│       └── webapp_controller.go     ← YOU EDIT THIS: your reconcile logic
├── config/
│   ├── crd/                         ← auto-generated CRD manifests
│   ├── rbac/                        ← auto-generated RBAC roles
│   └── manager/                     ← deployment manifest for the operator
├── cmd/
│   └── main.go                      ← entry point, registers your controller
└── go.mod
```

---

## Step 3 — Define your Custom Resource type

Edit `api/v1alpha1/webapp_types.go`:

```go
package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

// ─────────────────────────────────────────────────────────────────────────────
// WebappSpec — what the USER writes in their YAML (desired state)
// ─────────────────────────────────────────────────────────────────────────────
type WebappSpec struct {
    // Replicas is how many pods the user wants.
    // omitempty means: don't include this field in YAML if it's zero.
    Replicas int32 `json:"replicas,omitempty"`

    // Image is the Docker image to run (e.g. "nginx:alpine").
    // This field is required (no omitempty).
    Image string `json:"image"`
}

// ─────────────────────────────────────────────────────────────────────────────
// WebappStatus — what the CONTROLLER writes back (observed/actual state)
// ─────────────────────────────────────────────────────────────────────────────
type WebappStatus struct {
    // ReadyReplicas is how many pods are actually running.
    // The controller fills this in automatically.
    ReadyReplicas int32 `json:"readyReplicas,omitempty"`
}

// ─────────────────────────────────────────────────────────────────────────────
// Kubebuilder annotations — these drive code generation
// ─────────────────────────────────────────────────────────────────────────────

// +kubebuilder:object:root=true          → this type is a K8s resource (has metadata, spec, status)
// +kubebuilder:subresource:status        → status is a separate sub-resource (best practice)
// +kubebuilder:printcolumn:name="Replicas",type="integer",JSONPath=".spec.replicas"
// +kubebuilder:printcolumn:name="Ready",type="integer",JSONPath=".status.readyReplicas"
// ↑ these add columns to: kubectl get webapp

type Webapp struct {
    metav1.TypeMeta   `json:",inline"`       // apiVersion + kind
    metav1.ObjectMeta `json:"metadata,omitempty"` // name, namespace, labels, etc.

    Spec   WebappSpec   `json:"spec,omitempty"`
    Status WebappStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// WebappList is needed by the K8s API to return lists of Webapp objects.
type WebappList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    Items           []Webapp `json:"items"`
}

// Register both types with the scheme so the controller knows about them.
func init() {
    SchemeBuilder.Register(&Webapp{}, &WebappList{})
}
```

---

## Step 4 — Write the reconcile logic (Controller)

Edit `internal/controller/webapp_controller.go`:

```go
package controller

import (
    "context"

    appsv1  "k8s.io/api/apps/v1"
    corev1  "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/api/errors"
    metav1  "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/types"
    ctrl    "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/log"

    appsv1alpha1 "github.com/karim/my-operator/api/v1alpha1"
)

// ─────────────────────────────────────────────────────────────────────────────
// WebappReconciler holds the K8s client and the scheme.
// It is created once at startup in main.go.
// ─────────────────────────────────────────────────────────────────────────────
type WebappReconciler struct {
    client.Client          // lets us Get/Create/Update/Delete K8s objects
    Scheme *runtime.Scheme // knows about all registered types (Webapp, Deployment, etc.)
}

// ─────────────────────────────────────────────────────────────────────────────
// RBAC annotations — controller-gen reads these to generate ClusterRole manifests
// ─────────────────────────────────────────────────────────────────────────────

// +kubebuilder:rbac:groups=apps.example.com,resources=webapps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=apps.example.com,resources=webapps/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete

// ─────────────────────────────────────────────────────────────────────────────
// Reconcile is called automatically by controller-runtime every time:
//   - a Webapp CR is created, updated, or deleted
//   - a Deployment owned by a Webapp changes
//
// KEY PRINCIPLE: Reconcile must be IDEMPOTENT.
// It can be called 100 times in a row — the end result must always be the same.
// Think of it as: "make the world match what the user asked for".
// ─────────────────────────────────────────────────────────────────────────────
func (r *WebappReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    logger := log.FromContext(ctx)

    // ── Step 1: Fetch the Webapp CR that triggered this reconcile ────────────
    webapp := &appsv1alpha1.Webapp{}
    if err := r.Get(ctx, req.NamespacedName, webapp); err != nil {
        if errors.IsNotFound(err) {
            // The CR was deleted — nothing to do (K8s garbage-collects owned objects)
            return ctrl.Result{}, nil
        }
        // Unexpected error — requeue and retry
        return ctrl.Result{}, err
    }

    logger.Info("Reconciling Webapp",
        "name", webapp.Name,
        "replicas", webapp.Spec.Replicas,
    )

    // ── Step 2: Check if a Deployment already exists for this Webapp ─────────
    existingDeploy := &appsv1.Deployment{}
    err := r.Get(ctx, types.NamespacedName{
        Name:      webapp.Name,
        Namespace: webapp.Namespace,
    }, existingDeploy)

    if errors.IsNotFound(err) {
        // ── Step 3a: No Deployment yet → create one ──────────────────────────
        newDeploy := r.buildDeployment(webapp)
        logger.Info("Creating Deployment", "name", newDeploy.Name)

        if err := r.Create(ctx, newDeploy); err != nil {
            return ctrl.Result{}, err
        }
        // Return here — the Deployment creation will trigger another reconcile
        return ctrl.Result{}, nil

    } else if err != nil {
        // Unexpected read error
        return ctrl.Result{}, err
    }

    // ── Step 3b: Deployment exists → check if replicas need updating ─────────
    if *existingDeploy.Spec.Replicas != webapp.Spec.Replicas {
        existingDeploy.Spec.Replicas = &webapp.Spec.Replicas
        if err := r.Update(ctx, existingDeploy); err != nil {
            return ctrl.Result{}, err
        }
        logger.Info("Updated Deployment replicas", "replicas", webapp.Spec.Replicas)
    }

    // ── Step 4: Update the CR status with actual running replicas ────────────
    // This is what fills the READY column in: kubectl get webapp
    webapp.Status.ReadyReplicas = existingDeploy.Status.ReadyReplicas
    if err := r.Status().Update(ctx, webapp); err != nil {
        return ctrl.Result{}, err
    }

    // All good — no requeue needed (controller-runtime handles watch events)
    return ctrl.Result{}, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// buildDeployment constructs a Deployment object from the Webapp CR.
// The OwnerReference is critical: it tells K8s that this Deployment belongs
// to the Webapp — so if the Webapp is deleted, the Deployment is auto-deleted too.
// ─────────────────────────────────────────────────────────────────────────────
func (r *WebappReconciler) buildDeployment(webapp *appsv1alpha1.Webapp) *appsv1.Deployment {
    replicas := webapp.Spec.Replicas
    labels := map[string]string{"app": webapp.Name}

    return &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      webapp.Name,
            Namespace: webapp.Namespace,
            // OwnerReference = "this Deployment is a child of this Webapp"
            // When the Webapp CR is deleted, K8s automatically deletes this Deployment.
            OwnerReferences: []metav1.OwnerReference{
                *metav1.NewControllerRef(
                    webapp,
                    appsv1alpha1.GroupVersion.WithKind("Webapp"),
                ),
            },
        },
        Spec: appsv1.DeploymentSpec{
            Replicas: &replicas,
            Selector: &metav1.LabelSelector{
                MatchLabels: labels, // pods must have label app=<webapp-name>
            },
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{Labels: labels},
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{
                        {
                            Name:  "webapp",
                            Image: webapp.Spec.Image, // e.g. nginx:alpine
                            Ports: []corev1.ContainerPort{
                                {ContainerPort: 80},
                            },
                        },
                    },
                },
            },
        },
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SetupWithManager registers this controller with the manager.
// For() = watch Webapp resources
// Owns() = also react when a child Deployment changes
//           (e.g. someone manually deletes the Deployment → triggers reconcile)
// ─────────────────────────────────────────────────────────────────────────────
func (r *WebappReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&appsv1alpha1.Webapp{}).
        Owns(&appsv1.Deployment{}).
        Complete(r)
}
```

---

## Step 5 — Generate manifests and install the CRD

```bash
# Generate DeepCopy methods (required by K8s runtime for all types)
make generate

# Generate CRD YAML manifests from your Go annotations
make manifests

# Apply the CRD to your cluster
make install

# Verify the CRD is registered
kubectl get crd webapps.apps.example.com
# → webapps.apps.example.com   2026-05-05T...
```

---

## Step 6 — Run the operator locally

```bash
# This compiles and runs your controller locally.
# It connects to your cluster via ~/.kube/config (just like kubectl does).
make run
```

You should see:
```
INFO  setup   Starting manager
INFO  Starting workers  {"controller": "webapp", ...}
```

The operator is now **watching your cluster** from your WSL terminal.

---

## Step 7 — Test it

Open a **second terminal** and apply a Webapp CR:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps.example.com/v1alpha1
kind: Webapp
metadata:
  name: my-webapp
  namespace: default
spec:
  replicas: 2
  image: nginx:alpine
EOF
```

Now check what happened:

```bash
# Your custom resource
kubectl get webapp my-webapp
# NAME        REPLICAS   READY
# my-webapp   2          2

# The Deployment created automatically by your operator
kubectl get deployment my-webapp
# NAME        READY   UP-TO-DATE   AVAILABLE
# my-webapp   2/2     2            2

# The pods
kubectl get pods -l app=my-webapp
# NAME                         READY   STATUS    RESTARTS
# my-webapp-6d8f9b7c4d-xk2p9   1/1     Running   0
# my-webapp-6d8f9b7c4d-zt7m1   1/1     Running   0
```

In your first terminal (where `make run` is running), you should see:
```
INFO  Reconciling Webapp    {"name": "my-webapp", "replicas": 2}
INFO  Creating Deployment   {"name": "my-webapp"}
```

---

## Step 8 — Test the reconciliation loop

This is where operators become powerful. Try these scenarios:

### Scenario A — Scale up via the CR

```bash
kubectl patch webapp my-webapp --type=merge -p '{"spec":{"replicas":4}}'

# The operator detects the change and updates the Deployment
kubectl get deployment my-webapp
# → READY: 4/4
```

### Scenario B — Self-healing: delete the Deployment manually

```bash
kubectl delete deployment my-webapp

# Wait 2-3 seconds, then check:
kubectl get deployment my-webapp
# → The operator recreated it automatically!
```

> This works because of `Owns(&appsv1.Deployment{})` in `SetupWithManager`.
> The controller watches Deployments it owns — if one disappears, it reconciles immediately.

### Scenario C — Delete the CR

```bash
kubectl delete webapp my-webapp

# The Deployment is also deleted automatically (OwnerReference)
kubectl get deployment my-webapp
# → Error from server (NotFound)
```

---

## The reconcile loop — visualized

```
  User applies Webapp CR
          │
          ▼
     API Server ──────────► etcd (stored)
          │
          │ (watch event fires)
          ▼
    ┌─────────────────────────────────────────┐
    │           Reconcile() is called          │
    │                                         │
    │  1. Get Webapp CR from cluster          │
    │          │                              │
    │          ▼                              │
    │  2. Does Deployment exist?              │
    │      │              │                   │
    │     NO             YES                  │
    │      │              │                   │
    │      ▼              ▼                   │
    │  Create         Replicas match?         │
    │  Deployment      │         │            │
    │                 YES       NO            │
    │                  │         │            │
    │                  │       Update         │
    │                  │     Deployment       │
    │                  └────────┘             │
    │                      │                  │
    │                      ▼                  │
    │               Update CR Status          │
    │               (readyReplicas)           │
    └─────────────────────────────────────────┘
```

**Key rule:** Reconcile is always idempotent — calling it 10 times gives the same result as calling it once.

---

## Clean up

```bash
# Delete the CR (Deployment is auto-deleted via OwnerReference)
kubectl delete webapp my-webapp

# Uninstall the CRD from the cluster
make uninstall

# Stop the controller: Ctrl+C in the make run terminal
```

---

## Common errors & fixes

| Error | Cause | Fix |
|---|---|---|
| `go version go1.22.2 is incompatible` | Old Go in PATH | `sudo rm /usr/bin/go && hash -r && source ~/.bashrc` |
| `Command 'go' not found` | PATH not set | `echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc && source ~/.bashrc` |
| Deployment not created | Controller not running | Run `make run` in a separate terminal |
| `no matches for kind "Webapp"` | CRD not installed | Run `make install` |

---

## What to explore next

| Topic | How |
|---|---|
| Add a validation webhook (reject bad values) | `kubebuilder create webhook --kind Webapp --defaulting --programmatic-validation` |
| Deploy the operator inside the cluster | `make docker-build docker-push IMG=myregistry/my-operator:v0.1` then `make deploy` |
| Write unit tests (embedded API server) | `make test` |
| Official deep-dive | https://book.kubebuilder.io |

---

*Tested on WSL2 — Kubebuilder v4 / Go 1.23 / Kubernetes 1.29+*
