# HMM Roadmap

This document outlines the development roadmap for **HMM (Haskell Monorepo Manager)**. It serves as a guide for contributors and users to understand the current capabilities and future direction of the project.

> **Vision:** To provide a unified, tool-agnostic interface for managing Haskell monorepos of any scale—handling everything from builds and dependencies to CI optimization and releases.

---

## 📅 Milestones

### ✅ v1.1.1: The Foundation (Current Status)
*Focus: Core build management and dependency synchronization.*
- [x] **Single Source of Truth:** `hmm.yaml` configuration.
- [x] **Build Matrix:** Switch between GHC versions (`hmm use`).
- [x] **Metadata Sync:** Generate/update `stack.yaml`, `package.yaml`, and `hie.yaml`.
- [x] **Dependency Bounds:** Enforce global version bounds on local packages.
- [x] **Release Automation:** `hmm version` (bump) and `hmm update-deps`.
- [x] **Formatting:** Ormolu integration (`hmm format`).

### 🚧 v0.6: Interoperability & Developer Experience
*Focus: Making HMM the central task runner and playing nice with non-Stack tools.*
- [ ] **Task Runner (`hmm run`):** A unified script runner (like `npm run`) for common project tasks (repl, db-reset, etc.).
- [ ] **Cabal Interop:** Generate `cabal.project` alongside `stack.yaml` to support `cabal build` and HLS native workflows.
- [ ] **Scaffolding (`hmm new`):** CLI command to generate new packages with correct directory structure and bounds.

### 🔭 v0.7: Quality Assurance & Insights
*Focus: Visualization, linting, and health checks.*
- [ ] **Linting (`hmm lint`):** Integrate `hlint` execution across the monorepo with central config.
- [ ] **Dependency Graph (`hmm graph`):** Visualize internal package dependencies (Dot/Mermaid) to detect cycles.
- [ ] **Health Checks (`hmm doctor`):** Audit `hmm.yaml` for unused deps, missing paths, or configuration drift.

### 🚀 v1.0: Enterprise Scale
*Focus: Optimization for large teams and CI pipelines.*
- [ ] **Smart CI (`hmm affected`):** Analyze git history to run tests *only* on changed packages and their dependents.
- [ ] **Changelog Automation (`hmm changelog`):** Manage changelog fragments and compile them on release.
- [ ] **Advanced Publishing:** improved `hmm publish` with dry-runs and candidate checks.

---

## 🛠 Feature Specifications

### 1. Task Runner (`hmm run`)
**Goal:** Replace scattered Makefiles and shell scripts with centralized scripts in `hmm.yaml`.

- **Config:**

```yaml
  scripts:
    repl: "stack repl --no-load"
    db:reset: "docker-compose restart db"

```

**Usage:** `hmm run db:reset`

### 2. Interoperability (`cabal.project`)

**Goal:** Ensure the repo works flawlessly with `cabal`, `HLS`, and `Weeder` without manual config.

* **Action:** `hmm sync` will generate a `cabal.project` file that mirrors the active `stack.yaml` configuration (packages, bounds, allow-newer).

### 3. Scaffolding (`hmm new`)

**Goal:** reduce friction when adding new libraries or apps.

* **Usage:** `hmm new <name> --group <group>`
* **Action:**
1. Creates directory based on group path.
2. Generates `package.yaml` with project-wide bounds.
3. Registers package in `hmm.yaml`.

### 4. Smart CI (`hmm affected`)

**Goal:** Drastically reduce CI times for large monorepos.

* **Usage:** `hmm affected --base origin/main`
* **Output:** List of package names that need testing.
* **Logic:** `(Changed Files -> Packages) + (Downstream Dependents) = Target List`

### 5. Config Preservation

**Goal:** Ensure `hmm` commands do not strip comments from `hmm.yaml`.

* **Strategy:** Move from pure serialization to surgical text replacement for commands like `version` and `update-deps`.
