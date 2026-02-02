# HMM Roadmap

This document outlines the development roadmap for **HMM (Haskell Monorepo Manager)**. It serves as a guide for contributors and users to understand the current capabilities and future direction of the project.

> **Vision:** To provide a unified, tool-agnostic interface for managing Haskell monorepos of any scale—handling everything from builds and dependencies to CI optimization and releases.

---

## 📅 Milestones

### ✅ The Foundation (Current Status)

_Focus: Core build management and dependency synchronization._

- [x] **Single Source of Truth:** `hmm.yaml` configuration.
- [x] **Build Matrix:** Switch between GHC versions (`hmm use`).
- [x] **Metadata Sync:** Generate/update `stack.yaml`, `package.yaml`, and `hie.yaml`.
- [x] **Dependency Bounds:** Enforce global version bounds on local packages.
- [x] **Release Automation:** `hmm version` (bump) and `hmm update-deps`.
- [x] **Formatting:** Ormolu integration (`hmm format`).
- [x] **Task Runner (`hmm run`):** A unified script runner (like `npm run`) for common project tasks (repl, db-reset, etc.).
- [x] **Linting (`hmm lint`):** Runs `hlint` across all Haskell source files in the monorepo. Fails with exit code 1 if any file fails linting, suitable for CI integration.
- [ ] **Cabal Interop:** Generate `cabal.project` alongside `stack.yaml` to support `cabal build` and HLS native workflows.
- [ ] **Scaffolding (`hmm new`):** CLI command to generate new packages with correct directory structure and bounds.
- [ ] **Dependency Graph (`hmm graph`):** Visualize internal package dependencies (Dot/Mermaid) to detect cycles.
- [ ] **Health Checks (`hmm doctor`):** Audit `hmm.yaml` for unused deps, missing paths, or configuration drift.
- [ ] **Advanced Publishing:** improved `hmm publish` with dry-runs and candidate checks.
- [ ] **Smart CI (`hmm affected`):** Analyze git history to run tests _only_ on changed packages and their dependents.
- [ ] **Changelog Automation (`hmm changelog`):** Manage changelog fragments and compile them on release.

## Feature Details

### 2. Interoperability (`cabal.project`)

**Goal:** Ensure the repo works flawlessly with `cabal`, `HLS`, and `Weeder` without manual config.

- **Action:** `hmm sync` will generate a `cabal.project` file that mirrors the active `stack.yaml` configuration (packages, bounds, allow-newer).

### 3. Scaffolding (`hmm new`)

**Goal:** reduce friction when adding new libraries or apps.

- **Usage:** `hmm new <name> --group <group>`
- **Action:**

1. Creates directory based on group path.
2. Generates `package.yaml` with project-wide bounds.
3. Registers package in `hmm.yaml`.

### 4. Smart CI (`hmm affected`)

**Goal:** Drastically reduce CI times for large monorepos.

- **Usage:** `hmm affected --base origin/main`
- **Output:** List of package names that need testing.
- **Logic:** `(Changed Files -> Packages) + (Downstream Dependents) = Target List`
