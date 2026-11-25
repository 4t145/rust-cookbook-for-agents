# Rust Cookbook for Agents

**[English](./README.md) | [简体中文](./README.zh-CN.md)**

Opinionated, rational Rust coding guidelines and architectural patterns designed for AI coding agents (and human maintainers).

Available in two editions:
- **English**: [`AGENTS.md`](./AGENTS.md) *(token-compact default)*
- **简体中文**: [`AGENTS.zh-CN.md`](./AGENTS.zh-CN.md)

---

## Why This Exists

Modern LLMs know Rust syntax well, yet routinely produce un-idiomatic architectural anti-patterns when left unconstrained: bolting singleton `XxxExt` traits onto concrete structs, scattering parallel `Option` fields across structs, writing 300-line branching functions full of `let mut` flags, wrapping everything in `Arc<dyn Service>` + `async_trait`, or silently dropping uncommitted database transactions.

`rust-cookbook-for-agents` brings rationality back to AI-assisted Rust projects through crisp, enforceable structural rules:

1. **Module Architecture & Attention Preservation**: Ban `mod.rs`; mirror domain hierarchy in directory structure; enforce **Deep Modules & Narrow Interfaces** (`pub(crate)` by default, no pass-through shallow wrappers).
2. **Types as Documentation**: Bind mutually exclusive states with payload-bearing `enum`s; **Parse, don't validate** into `Newtype`s at boundaries; leverage standard conversion traits (`From` / `TryFrom` / `!`).
3. **Accessor Views Over Singleton `XxxExt` Traits**: Never invent one-to-one extension traits for concrete structs; encapsulate secondary namespaces and scoped parameters via `Accessor<C>` views.
4. **Typed Capabilities & Proof Tokens (`Committed<T>`)**: Hoist transaction/authorization capabilities to the orchestration layer and enforce terminal actions (such as `tx.commit()`) in return signatures.
5. **Typestate for Complex Branching Flows**: Decompose monolithic multi-branch functions using `Flow<S>` state nodes + transition enums, destroying stale phase locals via move semantics.
6. **Concurrency, Layered Errors & Verification Loop**: Native async, short synchronous locks never held across `.await`, Actor handles over shared `Arc<Mutex<BigState>>`, layered `thiserror` / `anyhow`, and mandatory `clippy` + `fmt` + `test` verification.

---

## Quick Start

### Option 1: `rcfa` CLI Helper (Recommended for Multi-Project Sync)

Install once to symlink `AGENTS.md` into any new or cloned Rust repository **without polluting `git status`** (automatically added to `.git/info/exclude`), and sync upstream updates across all projects with one command:

```bash
# Install (defaults to English AGENTS.md; pass `-s -- --zh` to default to Chinese)
curl -fsSL https://rcfa.4t145.com/install.sh | bash
```

Daily usage inside any Rust project root:

```bash
rcfa              # Symlink AGENTS.md + add to .git/info/exclude (or layer into .agents/rules/ if AGENTS.md already exists)
rcfa --zh         # Symlink the Chinese edition (AGENTS.zh-CN.md -> ./AGENTS.md)
rcfa copy         # Copy a standalone AGENTS.md file (when you want to commit it to Git)
rcfa update       # Pull latest upstream changes (instantly updates all symlinked projects)
rcfa unlink       # Remove the symlink from the current project
```

### Option 2: Zero-Install Single-File Fetch

Drop directly into any Rust repository (compatible with Codex, Claude Code, Cursor, Antigravity, Zed, etc.):

```bash
# English edition
curl -fsSL https://rcfa.4t145.com/AGENTS.md -o AGENTS.md

# Chinese edition (简体中文)
curl -fsSL https://rcfa.4t145.com/AGENTS.zh-CN.md -o AGENTS.md
```

*(If your tool reads `CLAUDE.md`, write `-o CLAUDE.md` or run `ln -s AGENTS.md CLAUDE.md`.)*

### Option 3: Antigravity Global Plugin

Clone directly into your Antigravity global plugins directory so the rules apply automatically across workspaces without per-repo files:

```bash
git clone https://github.com/4t145/rust-cookbook-for-agents.git ~/.gemini/config/plugins/rust-cookbook-for-agents
```

---

## License

Released under the [MIT License](./LICENSE).
