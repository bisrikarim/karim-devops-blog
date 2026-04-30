# karim.devops

> DevOps / SRE / Platform Engineering

Personal tech blog — [karimdevops.github.io](https://karimdevops.github.io)

Built with [Hugo](https://gohugo.io/) + [PaperMod](https://github.com/adityatelange/hugo-PaperMod). Deployed to GitHub Pages via GitHub Actions. Comments via [Giscus](https://giscus.app/).

---

## Run locally

```bash
# 1. Clone with submodules (theme)
git clone --recurse-submodules https://github.com/karimdevops/karimdevops.github.io.git
cd karimdevops.github.io

# 2. Install Hugo extended (if not installed)
make install-hugo

# 3. Serve with drafts
make run
```

Visit `http://localhost:1313`

---

## Write a post

```bash
# Interactive
make new

# Or directly
hugo new posts/kubernetes/my-post-title.md
```

Edit the file in `content/posts/<section>/`. Set `draft: false` when ready to publish.

Post structure:
```
---
title: "Your Title"
date: 2024-01-01
draft: false
tags: ["kubernetes", "devops"]
description: "One line summary."
showToc: true
comments: true
---

## Context
## Problem
## Solution
## Implementation
## Conclusion
```

Push to `main` → GitHub Actions builds and deploys automatically.

---

## Content sections

| Path | Purpose |
|------|---------|
| `content/posts/kubernetes/` | K8s, Helm, operators |
| `content/posts/cicd/` | GitLab, ArgoCD, FluxCD |
| `content/posts/observability/` | Prometheus, Grafana, Loki |
| `content/posts/azure/` | Cloud, Azure DevOps |
| `content/posts/platform-engineering/` | IDP, platform topics |
| `content/about/` | About page |
| `content/uses/` | Uses page |
| `content/projects/` | Projects page |

---

## Deployment

Push to `main` triggers:

1. **Lint** — markdownlint on all content
2. **Build** — Hugo extended with minification
3. **Deploy** — GitHub Pages via `actions/deploy-pages`

Pull requests trigger build-only (preview artifact uploaded, no deploy).

---

## Configure Giscus comments

1. Go to [giscus.app](https://giscus.app)
2. Enter your repo: `karimdevops/karimdevops.github.io`
3. Enable GitHub Discussions on the repo (Settings → Features)
4. Create a Discussion category named `Blog Comments`
5. Copy `data-repo-id` and `data-category-id`
6. Paste into `layouts/partials/comments.html`

---

## Theme customization

- **Font**: Consolas monospace everywhere (`static/css/custom.css`)
- **Colors**: CSS variables in `:root` and `.dark` — edit `custom.css`
- **Layout overrides**: `layouts/partials/`

---

## Stack

```
generator:  Hugo extended
theme:      PaperMod (customized)
hosting:    GitHub Pages
ci/cd:      GitHub Actions
comments:   Giscus (GitHub Discussions)
font:       Consolas monospace
```
