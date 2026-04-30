---
title: "Projects"
date: 2024-01-01
draft: false
comments: false
showToc: true
---

_Open source tools, experiments, and side projects. Most are infrastructure-focused or AI-applied DevOps._

---

## AI-Powered Code Review System

**Stack**: GitLab CI/CD, Ollama, Qwen2.5-Coder, Python

Automated code review integrated directly into GitLab merge requests. Every MR triggers an on-premise LLM analysis — no code leaves the network. The model reviews logic, security anti-patterns, and Dockerfile/IaC quality, then posts structured feedback as a GitLab comment.

- 100% on-premise — no OpenAI API keys, no data exfiltration
- Works with air-gapped environments
- Supports custom prompts per repo / language

```
gitlab-ci → trigger → ollama (local) → qwen2.5-coder → MR comment
```

> Status: Internal use at Sofrecom · Private repo

---

## Infra Documentation Generator (Multi-Agent)

**Stack**: smolagents, Hugging Face, Python, CPU-only

A multi-agent pipeline that auto-generates infrastructure documentation from Git repositories. Three agents collaborate: an **Explorer** (maps the repo structure), a **Reader** (extracts config intent), and a **Writer** (produces structured Markdown README).

Runs entirely on CPU — no GPU required. Designed for teams without cloud access who need living documentation.

```
repo → Explorer → Reader → Writer → README.md
```

> Status: Experimental · [github.com/bisrikarim](https://github.com/bisrikarim)

---

## AI Log Analyzer

**Stack**: n8n, Ollama, Mistral 7B, Prometheus, Loki

n8n workflow that pulls logs from Loki/Elasticsearch, sends them to a local Mistral 7B instance, and produces a structured anomaly report — with root cause hypotheses and suggested remediation steps. Runs on a closed circuit: zero cloud dependencies.

```
loki → n8n trigger → mistral 7B (ollama) → anomaly report → alert
```

> Status: Proof of concept · Internal

---

## Terraform AWX Provisioner

**Stack**: Terraform, Kubernetes, Helm, AWX Operator

Reusable Terraform modules for deploying AWX on-demand on any Kubernetes cluster. Parameterized by environment (dev / staging / prod). Supports multi-cluster provisioning from a single pipeline run.

Reduced AWX provisioning time by ~60% compared to manual deployment.

> Status: Production use · Private

---

## Kubespray Upgrade Automation

**Stack**: Ansible, Kubespray, GitLab CI/CD, Python

Automated pipeline for Kubernetes cluster upgrades using Kubespray. Includes pre-flight checks, etcd health validation, rolling node upgrades, and post-upgrade smoke tests. Handles AWX Operator version migrations (e.g., 2.7.6 → 2.19.1).

> Status: Production use · Internal

---

_More on [GitHub →](https://github.com/bisrikarim)_
