---
title: "introduction to ML"
date: 2026-05-04
draft: false
tags: ["ML"]
description: "Introduction to Basic ML Concepts"
showToc: true
comments: true
---

# 🤖 Machine Learning — A Practical Intro for DevOps Engineers

> You already know pipelines, automation, monitoring, and deployments.  
> ML is just another system to build, run, and maintain — with a twist: **the system learns from data**.

---

## 🧭 Table of Contents

1. [What is Machine Learning?](#1-what-is-machine-learning)
2. [Key Concepts](#2-key-concepts)
   - [Dataset](#21-dataset)
   - [Features & Labels](#22-features--labels)
   - [Model](#23-model)
   - [Training](#24-training)
   - [Inference](#25-inference)
   - [Overfitting & Underfitting](#26-overfitting--underfitting)
3. [Types of ML](#3-types-of-ml)
   - [Supervised Learning](#31-supervised-learning)
   - [Unsupervised Learning](#32-unsupervised-learning)
   - [Reinforcement Learning](#33-reinforcement-learning)
4. [Common Algorithms (Simply Explained)](#4-common-algorithms-simply-explained)
5. [DevOps vs MLOps — Similarities & Differences](#5-devops-vs-mlops--similarities--differences)
6. [Your Mental Model](#6-your-mental-model)

---

## 1. What is Machine Learning?

In traditional programming, **you write the rules**:

```python
# Classic "if-else" rule
def is_spam(email):
    if "win a prize" in email:
        return True
    return False
```

In Machine Learning, **you give the program examples and it figures out the rules itself**:

```python
# You don't write rules — you feed examples
emails = ["win a prize now!", "meeting at 3pm", "free money!!!"]
labels = ["spam",             "not spam",       "spam"]

# The model learns the pattern from the data
model.fit(emails, labels)

# Then it predicts on new emails it's never seen
model.predict(["you won a lottery!"])  # → "spam"
```

> 💡 **DevOps analogy**: Think of it like writing a Dockerfile vs. having a system that watches how your app runs and auto-generates the Dockerfile for you.

---

## 2. Key Concepts

### 2.1 Dataset

A **dataset** is just a collection of examples your model will learn from. It's your training material.

```
| CPU Usage | Memory Usage | Disk I/O | Is Anomaly? |
|-----------|-------------|----------|-------------|
| 95%       | 80%         | High     | Yes         |
| 20%       | 30%         | Low      | No          |
| 90%       | 85%         | High     | Yes         |
```

> 💡 **DevOps analogy**: It's like your logs and metrics history — the raw material to learn from.

---

### 2.2 Features & Labels

- **Features** = the inputs (what you know)
- **Label** = the output (what you want to predict)

```python
# Features = inputs your model reads
features = [cpu_usage, memory_usage, disk_io]

# Label = what you want to predict
label = is_anomaly  # True or False
```

> 💡 **DevOps analogy**: Features are like your Prometheus metrics. The label is the alert you're trying to predict.

---

### 2.3 Model

A **model** is the "brain" — a mathematical function that maps features → label.  
Think of it as a black box that gets smarter over time.

```python
from sklearn.tree import DecisionTreeClassifier

model = DecisionTreeClassifier()  # Create the model (empty brain)
```

---

### 2.4 Training

**Training** = feeding the model your data so it learns the patterns.  
This is a CPU/GPU-heavy process. It only happens once (or periodically).

```python
# X = features, y = labels
X = [[95, 80, 1], [20, 30, 0], [90, 85, 1]]
y = [1, 0, 1]  # 1 = anomaly, 0 = normal

model.fit(X, y)  # ← this is "training"
print("Training done! Model is ready.")
```

> 💡 **DevOps analogy**: Training is like `docker build` — it's a one-time (or scheduled) heavy operation that produces an artifact.

---

### 2.5 Inference

**Inference** = using the trained model to make predictions on new, unseen data.  
This is the "production" step — fast and lightweight.

```python
new_server_metrics = [[92, 78, 1]]  # New data, never seen before

prediction = model.predict(new_server_metrics)
print(prediction)  # → [1] meaning: "This looks like an anomaly!"
```

> 💡 **DevOps analogy**: Inference is like `docker run` — you use the artifact you built to do the actual work.

---

### 2.6 Overfitting & Underfitting

These are the two most common problems in ML:

| Problem | What it means | Analogy |
|---|---|---|
| **Overfitting** | Model memorized training data, fails on new data | A config that works only in dev, breaks in prod |
| **Underfitting** | Model is too simple, can't learn the pattern | A monitoring rule so vague it never triggers |

```python
# Overfitting: model is too complex, memorizes noise
model = DecisionTreeClassifier(max_depth=100)  # 🚨 Too deep!

# Underfitting: model is too simple
model = DecisionTreeClassifier(max_depth=1)    # 🚨 Too shallow!

# Just right
model = DecisionTreeClassifier(max_depth=5)   # ✅ Balanced
```

---

## 3. Types of ML

### 3.1 Supervised Learning

You give the model **labeled examples** (inputs + correct answers).  
It learns to predict the answer for new inputs.

**Use cases**: spam detection, anomaly detection, price prediction.

```python
# You have both: inputs AND correct answers
X = [[95, 80], [20, 30], [88, 75]]  # metrics
y = [1, 0, 1]                        # labels: anomaly or not

model.fit(X, y)
model.predict([[91, 77]])  # → [1] (anomaly)
```

---

### 3.2 Unsupervised Learning

You give the model **data without labels**.  
It finds patterns and groups on its own.

**Use cases**: customer segmentation, log clustering, anomaly detection (without labeled data).

```python
from sklearn.cluster import KMeans

# No labels — just raw metrics
X = [[95, 80], [20, 30], [22, 35], [90, 82]]

model = KMeans(n_clusters=2)
model.fit(X)

print(model.labels_)  # → [1, 0, 0, 1]
# It found 2 groups on its own: "high load" and "normal"
```

---

### 3.3 Reinforcement Learning

An **agent** learns by trying actions and receiving rewards or penalties.  
No dataset needed — it learns by doing.

**Use cases**: game AI, auto-scaling policies, robotics.

```
Agent tries action → Gets reward (+) or penalty (-) → Adjusts strategy → Repeat
```

> 💡 **DevOps analogy**: Like an autoscaler that tries different scaling rules, measures response time, and learns which rules work best over time.

---

## 4. Common Algorithms (Simply Explained)

### Linear Regression
Predicts a **number** (e.g., "how much RAM will this service use in 1 hour?").  
Draws the best straight line through your data points.

```python
from sklearn.linear_model import LinearRegression

X = [[1], [2], [3], [4]]   # hours
y = [10, 20, 30, 40]        # MB of RAM used

model = LinearRegression()
model.fit(X, y)
model.predict([[5]])  # → [50.0] MB predicted
```

---

### Decision Tree
Makes decisions by asking yes/no questions — like a flowchart.

```
CPU > 90%?
├── Yes → Memory > 70%? 
│         ├── Yes → ANOMALY
│         └── No  → OK
└── No  → OK
```

```python
from sklearn.tree import DecisionTreeClassifier

model = DecisionTreeClassifier(max_depth=3)
model.fit(X_train, y_train)
model.predict(X_new)
```

---

### Neural Network
Loosely inspired by the brain. Stacks many layers of math operations.  
Used for complex tasks: images, language, voice.

```python
# Think of it as: input → hidden layers → output
# Each layer transforms the data a bit more

import tensorflow as tf

model = tf.keras.Sequential([
    tf.keras.layers.Dense(16, activation='relu'),  # layer 1
    tf.keras.layers.Dense(8,  activation='relu'),  # layer 2
    tf.keras.layers.Dense(1,  activation='sigmoid') # output
])
```

> 💡 **DevOps analogy**: Like chaining multiple bash commands — each one transforms the data a bit until you get your final result.

---

## 5. DevOps vs MLOps — Similarities & Differences

MLOps = DevOps applied to Machine Learning pipelines.  
If you know DevOps, you're already 50% there.

### ✅ What's the Same

| DevOps concept | MLOps equivalent |
|---|---|
| CI/CD pipelines | Training pipelines |
| Build artifacts (Docker images) | Model artifacts (`.pkl`, `.onnx` files) |
| Versioning code (Git) | Versioning code + data + models |
| Deploying services | Deploying model endpoints (APIs) |
| Monitoring (CPU, latency) | Monitoring (accuracy, data drift) |
| Rollback bad deploys | Rollback to previous model version |
| Staging environments | Experiment tracking (try many models) |

### ⚠️ What's Different

| DevOps | MLOps |
|---|---|
| Code is deterministic | Models are probabilistic |
| A passing test = working code | A good metric ≠ good model in production |
| Code doesn't "degrade" over time | Models degrade when real data changes (data drift) |
| You version code | You version code + data + model weights |
| Deploy once, runs forever | Must retrain periodically as data evolves |
| Bugs are in code | Bugs can be in data, labels, or model architecture |

### 🔄 A Typical MLOps Pipeline

```
Data Collection → Data Validation → Feature Engineering
      ↓
  Model Training → Model Evaluation → Model Registry
      ↓
  Model Deployment (API/container) → Monitoring
      ↓
  Data Drift Detected → Retrain → Repeat
```

> 💡 Compare with a CI/CD pipeline:
> ```
> Code Commit → Lint/Test → Build → Deploy → Monitor → Incident → Fix → Repeat
> ```
> Same loop. Different artifacts and failure modes.

---

## 6. Your Mental Model

Here's everything distilled into one mental model for you:

```
TRADITIONAL SOFTWARE          MACHINE LEARNING
─────────────────────         ─────────────────────
Rules    → Output             Data + Output → Rules
Code     → App                Data         → Model
Deploy   → Done               Deploy       → Monitor → Retrain
Bug in code                   Bug in data, labels, or distribution shift
```

**Your DevOps superpowers that transfer directly to MLOps:**
- Pipeline thinking ✅
- Infrastructure as Code ✅
- Monitoring & alerting ✅
- Containerization (models run in Docker too) ✅
- Version control discipline ✅
- Incident response mindset ✅

**New skills you'll need to add:**
- Understanding model evaluation metrics (accuracy, precision, recall)
- Spotting data drift (when real-world data changes over time)
- Experiment tracking tools (MLflow, Weights & Biases)
- Feature stores and data versioning (DVC)

---

> 🎯 **Bottom line**: ML is a new kind of artifact in your pipeline. Instead of compiling code into a binary, you train data into a model. Everything else — versioning, deploying, monitoring, rolling back — is a problem you already know how to solve.
