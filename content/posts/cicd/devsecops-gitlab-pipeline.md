---
title: "Building a DevSecOps Pipeline with GitLab CI/CD"
date: 2024-04-10
draft: false
tags: ["cicd", "devsecops", "gitlab", "security", "trivy"]
description: "How to integrate Trivy, Gitleaks, SonarQube and SBOM generation into a production GitLab pipeline."
showToc: true
comments: true
---

## Context

Security scanning that runs after deployment is not security — it's incident response. This post shows how to shift security left in a GitLab CI/CD pipeline without killing developer velocity.

## Problem

Most teams bolt on security tools at the end of the pipeline or run them nightly. This creates a feedback loop measured in hours, not seconds. Developers lose context. Vulnerabilities accumulate.

## Solution

Integrate scanning at every stage: code → image → deployment.

```
code push → lint+SAST → build image → scan image → SBOM → deploy
```

## Implementation

```yaml
# .gitlab-ci.yml
stages:
  - lint
  - build
  - scan
  - deploy

variables:
  IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA

gitleaks:
  stage: lint
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks detect --source . --redact
  allow_failure: false

sonarqube:
  stage: lint
  image: sonarsource/sonar-scanner-cli:latest
  script:
    - sonar-scanner -Dsonar.projectKey=$CI_PROJECT_NAME
  only:
    - merge_requests
    - main

build:
  stage: build
  image: docker:24
  services: [docker:24-dind]
  script:
    - docker build -t $IMAGE .
    - docker push $IMAGE

trivy-scan:
  stage: scan
  image: aquasec/trivy:latest
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL $IMAGE
    - trivy image --format cyclonedx --output sbom.json $IMAGE
  artifacts:
    paths: [sbom.json]
    reports:
      container_scanning: sbom.json

deploy:
  stage: deploy
  script:
    - helm upgrade --install myapp ./chart --set image.tag=$CI_COMMIT_SHORT_SHA
  environment:
    name: production
  only: [main]
```

Key decisions:

- `gitleaks` blocks on secrets — `allow_failure: false` is intentional
- `trivy` exits non-zero on HIGH/CRITICAL — pipeline fails before deploy
- SBOM generated as CycloneDX artifact for audit trail

## Conclusion

Shifting left means making security fast enough that developers don't bypass it. Each scan above adds < 2 minutes. Total pipeline: ~8 minutes. The 60% reduction in over-privileged access we achieved at Sofrecom started here — with visibility before deployment, not after.
