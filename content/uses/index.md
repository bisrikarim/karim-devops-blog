---
title: "Uses"
date: 2024-01-01
draft: false
comments: false
showToc: true
---

_Tools, hardware, and software I use daily. Updated occasionally._

## Terminal & Shell

- **Terminal**: [Alacritty](https://alacritty.org/) — GPU-accelerated, zero latency
- **Shell**: Zsh + [Oh My Zsh](https://ohmyz.sh/) with minimal plugins
- **Prompt**: [Starship](https://starship.rs/) — fast, context-aware, monospace-friendly
- **Multiplexer**: [tmux](https://github.com/tmux/tmux) with custom key bindings
- **File manager**: `ranger` for TUI, `fzf` for fuzzy-finding everything

## Editor

- **Primary**: [Neovim](https://neovim.io/) — Lua config, LSP, Telescope
- **Secondary**: [VS Code](https://code.visualstudio.com/) for pair programming / remote SSH
- **Font**: [JetBrains Mono](https://www.jetbrains.com/lp/mono/) — ligatures off, weight 400
- **Theme**: Dark, low-contrast (no neon)

## Infrastructure & Dev Tools

```
kubernetes:    kubectl, helm, k9s, kubectx, stern
terraform:     terraform, terragrunt, tfsec
ansible:       ansible, ansible-lint, molecule
containers:    docker, podman, dive, hadolint
secrets:       vault, age, sops
git:           git, lazygit, delta (diff viewer)
api:           httpie, jq, yq
monitoring:    k9s, grafana (browser), promtool
```

## Hardware

- **Laptop**: Dell Latitude (Linux, Ubuntu 24.04 LTS)
- **External monitor**: 27" 1440p — gives enough room for 2 terminals + browser
- **Keyboard**: TKL mechanical, linear switches
- **Headphones**: Sony WH-1000XM — noise cancelling for deep work

## Operating System

- **Primary OS**: Ubuntu 24.04 LTS
- **VMs**: Vagrant + libvirt for local infra testing
- **Container runtime**: containerd / Docker Desktop on dev machines

## Browsers & Productivity

- **Browser**: Firefox with uBlock Origin, no telemetry
- **Notes**: Markdown files in a Git repo — no cloud apps
- **Diagrams**: `draw.io` (offline), Mermaid in Markdown
- **Communication**: Mattermost (self-hosted preferred), Matrix

## This Blog

Built with [Hugo](https://gohugo.io/) + [PaperMod](https://github.com/adityatelange/hugo-PaperMod), deployed to GitHub Pages via GitHub Actions. Comments via [Giscus](https://giscus.app/) (GitHub Discussions). No analytics, no trackers.

Source: [github.com/karimdevops/karimdevops.github.io](https://github.com/karimdevops/karimdevops.github.io)
