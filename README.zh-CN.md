# Rust Cookbook for Agents

**[English](./README.md) | [简体中文](./README.zh-CN.md)**

面向 AI 编程代理（及人类维护者）的理性 Rust 编码规范与架构正范式。

提供中英双语版本，内容一一对应：
- **English**：[`AGENTS.md`](./AGENTS.md) *（默认版本，Token 占用更紧凑）*
- **简体中文**：[`AGENTS.zh-CN.md`](./AGENTS.zh-CN.md)

---

## 设计初衷：把理性带回 Rust 项目

如今的大模型早已熟悉 Rust 基础语法，但在缺乏架构约束时，极易惯性写出背离 Rust 哲学的反模式：给具体结构体乱套“一配一”的 `XxxExt` 拓展 Trait、用平行 `Option` 字段拼凑非法状态、写出堆满 `let mut` 标志位的几百行巨石分支函数、无脑套 `Arc<dyn Service>` 倒逼引入 `async_trait`、或在长链路中漏调事务 `commit` 导致静默回滚。

本仓库将经过实战检验的 Rust 正范式提炼为 AI 可严格执行的硬约束：

1. **模块架构与注意力保护**：禁用 `mod.rs`，目录层级严格映射领域概念；坚持**深模块、窄接口**（默认私有或 `pub(crate)`，拒绝无实质收益的薄皮透传函数）。
2. **类型即文档**：用带载荷 `enum` 绑定互斥状态，系统入口遵循 **Parse, don't validate** 解析为 `Newtype`，积极使用标准转换 Trait 与 `1.100` 稳定的 `!` 类型。
3. **访问器（Accessor）优于具象 `XxxExt`**：禁止为具体 `struct` 定义单例拓展 Trait，使用访问器视图建立二级命名空间并绑定局部上下文参数。
4. **类型化能力与结果凭据（`Committed<T>`）**：将事务与鉴权能力上交编排层并显式回传，利用私有构造凭据在返回类型上封死漏调 `commit` 的风险。
5. **类型状态（Typestate）解耦复杂流转**：用 `Flow<S>` 状态节点 + 跃迁枚举拆解巨石分支函数，借 Move 语义在编译期销毁过期阶段状态。
6. **并发、分层错误与交付闭环**：原生异步、短同步锁严禁跨 `.await`、复杂异步状态优先 Actor 模式；`thiserror` / `anyhow` 内外分层；强制执行 `clippy` + `fmt` + `test` 交付闭环。

---

## 快速接入

### 方式 1：安装 `rust-ai` 命令行工具（推荐：多项目软链接 + 一键热更新，不污染 Git）

安装一次后，每次新建或拉取任何开源/团队 Rust 项目只需敲一行 `rust-ai`，即可自动软链接规范并写入 `.git/info/exclude`（Git 本地私有忽略，`git status` 完全干净）：

```bash
# 默认挂载英文版（更省 Token）；若偏好默认挂载中文版可在末尾加 ` -s -- --zh`
curl -fsSL https://raw.githubusercontent.com/4t145/rust-cookbook-for-agents/main/install.sh | bash
```

在任意 Rust 项目根目录下的日常用法：

```bash
rust-ai           # 软链接 AGENTS.md 并加入本地 Git 忽略（若项目已有团队 AGENTS.md，会自动挂载到 .agents/rules/ 叠加生效）
rust-ai --zh      # 软链接中文版规范（AGENTS.zh-CN.md -> ./AGENTS.md）
rust-ai copy      # 拷贝独立实体文件到当前目录（适合需要随项目提交 Git 的场景，可配 --zh）
rust-ai update    # 拉取 GitHub 最新规范，本机所有软链接过的项目瞬间同步生效
rust-ai unlink    # 移除当前项目的软链接
```

### 方式 2：零安装单项目直接拉取

无需克隆仓库，直接下载至任意 Rust 项目根目录（通用于 Antigravity、Claude Code、Codex、Cursor、Zed 等工具）：

```bash
# 拉取英文版（Token 更紧凑）
curl -fsSL https://raw.githubusercontent.com/4t145/rust-cookbook-for-agents/main/AGENTS.md -o AGENTS.md

# 拉取简体中文版
curl -fsSL https://raw.githubusercontent.com/4t145/rust-cookbook-for-agents/main/AGENTS.zh-CN.md -o AGENTS.md
```

*（若使用的工具读取 `CLAUDE.md`，可将 `-o AGENTS.md` 改为 `-o CLAUDE.md`，或执行 `ln -s AGENTS.md CLAUDE.md`。）*

### 方式 3：作为 Antigravity 全局插件使用（免单项目挂载）

直接克隆至全局插件目录，本机所有工作区自动常驻加载，随时 `git pull` 更新：

```bash
git clone https://github.com/4t145/rust-cookbook-for-agents.git ~/.gemini/config/plugins/rust-cookbook-for-agents
```

---

## 开源协议

基于 [MIT License](./LICENSE) 发布，可自由复制、修改并用于个人或商业项目。
