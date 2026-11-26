# Rust Coding Guidelines

These guidelines apply strictly to hand-written source code in this repository, not to generated code.

---

## 0. Core Philosophy: Quality, Gestalt & *Shì* (势)

**Coding is in essence complex systems engineering—it demands a holistic grasp of the system rather than the mechanical assembly of isolated code fragments.** What we call "code quality" is, in its deeper sense, **Quality** (*良质*) itself: something that cannot be exhausted by a single local metric or a one-line definition, yet can be perceived across facets—as **Gestalt** (a whole greater than the sum of its parts), as ***Shì* (势)** (the relational configuration and tension among elements), and as **engineering art and aesthetics**.

Approach complex systems holistically and reject keyhole-style local patching:

- **Whole Before Part**: No struct, function, or module holds meaning in isolation; its meaning lives in its relationships with everything around it. Step back to perceive the surrounding topology and context before editing so new code grows naturally from the existing grain without bolted-on seams.
- **Shape Code Through Relationships**: Conceptually peer modules and dual operations should share symmetric structures and naming rhythms; subordinate details should recede beneath narrow interfaces; tightly coupled state and behavior belong together, while orthogonal concerns keep clear boundaries.
- **Use Aesthetic Intuition to Detect Imbalance**: Ugly, contorted code riddled with special cases and pass-through patches is rarely a mere stylistic blemish—it is an alarm that a local change has broken the system's Gestalt and *Shì*. When a new requirement feels awkward to force in, never jam it in just to minimize a local diff; return to the whole-system view, realign conceptual boundaries, and implement cleanly within the reshaped design.

---

## 1. Module Architecture & Code Organization

### Submodules & Static Assets

Organize submodules using the `<module>.rs` + `<module>/` directory convention. **NEVER** use `mod.rs`. Place hard-coded static assets (such as JSON templates or long text fixtures) under `<module>/assets/`, and isolate white-box unit tests in `tests.rs`:

```text
🦀 <module>.rs
  +-- 📂 <submodule>
  |     +-- 📂 assets
  |     |     +-- 📄 hard-coded-config.json
  |     |     +-- 📄 some-long-text.txt
  |     +-- 🦀 <submodule_a>.rs
  |     +-- 🦀 <submodule_b>.rs
  |     +-- 🧪 tests.rs
  +-- 🦀 <submodule>.rs
```

### Directory Hierarchy Mirrors Conceptual Hierarchy

Structure module trees around domain concepts and abstraction levels. Sibling files in the same directory must represent peer concepts at the same architectural level—never flatten subordinate implementations alongside core domain concepts.

**Good ✅**: Group subordinate implementations and domain models into dedicated subdirectories

```text
🦀 payment.rs
  +-- 📂 impls
  |     +-- 🦀 <impl_a>.rs
  |     +-- 🦀 <impl_b>.rs
  +-- 🦀 impls.rs
  +-- 🦀 audit.rs
  +-- 🦀 model.rs
  +-- 📂 model
  |     +-- 🦀 bill.rs
  |     +-- 🦀 credits.rs
  +-- 🧪 tests.rs
```

**Bad 🚫**: Flat layout mixing concrete implementations, domain models, and cross-cutting concerns

```text
🦀 payment.rs
  +-- 🦀 <impl_a>.rs
  +-- 🦀 <impl_b>.rs
  +-- 🦀 audit.rs
  +-- 🦀 bill.rs
  +-- 🦀 credits.rs
  +-- 🧪 tests.rs
```

### Deep Modules & Narrow Interfaces

Maintainer and AI attention is a scarce resource. Design modules for **progressive disclosure of complexity**, keeping the cognitive width at each layer narrow:

- **Narrow Interfaces (Private by Default, Deliberate Exposure)**: Keep struct fields, helper functions, and internal types private or `pub(crate)` by default. Expose only the minimal high-level API surface required by callers, without leaking underlying implementation mechanisms into public signatures.
- **Deep Modules (No Pass-Through Shallow Wrappers)**: Break overly long functions into focused, single-responsibility helpers—but **do not extract trivial, single-call code snippets without independent domain meaning into thin pass-through functions**. Every layer of indirection must pay for its navigation cost by genuinely hiding complexity or enabling reuse.
- **Curated Re-exports**: Relatively self-contained modules should re-export their cohesive public API from the module root so callers can import cleanly without coupling to internal file splits, keeping `use` statements and Git diffs minimal.

---

## 2. Type Semantics & API Design

Types and signatures are the most reliable form of documentation. Prioritize **semantic correctness** for both long-term maintainability and AI comprehension.

### Make Illegal States Unrepresentable

1. **Bind Mutually Exclusive States with Payload-Bearing `enum`s**: Never represent phase-dependent data by combining a status field with parallel `Option` fields on a struct (e.g., storing `status`, `result: Option<T>`, and `error: Option<E>` side by side). Model them directly as `enum TaskState { Pending, Running { started_at: Instant }, Done(T), Failed(E) }`. Prefer exhaustive `match` arms and avoid wildcard `_` arms so the compiler flags every call site affected when a new variant is added.
2. **Parse, Don't Validate & Newtypes**: Parse raw inputs once at system boundaries via `TryFrom` / `FromStr` into invariant-preserving `Newtype`s (e.g., `UserId`, `Email`) or self-describing `enum`s. Trust type invariants inside the core domain instead of repeating defensive validation. Avoid ambiguous positional `bool` or bare `Option` parameters (reject unreadable call sites like `foo(false, None)`).
3. **Avoid Raw Tuples**: Do not abuse anonymous tuples as function parameters or return types; define named structs with explicit field semantics.

### Use Standard Type Conversion Traits

Actively leverage Rust's standard conversion traits—`From` / `Into`, `TryFrom` / `TryInto`, and `FromStr` / `Display`—instead of inventing ad-hoc conversion method names. When implementing fallible generic traits for infallible cases, use the `!` (never) type stabilized in Rust `1.100` as the associated error type.

### Intentional Naming & Eliminating Redundancy

Names must immediately convey responsibility while relying on lexical context to avoid redundant prefixes:

1. **Leverage Module Namespaces**: A request type inside the `system` module should be named `Request` and referenced as `system::Request`, not `SystemRequest`. *Exception*: When models from multiple submodules are flattened and re-exported through a unified `model` prelude where the submodule path is lost, retaining the domain prefix (e.g., `BillingRecord`) is appropriate.
2. **Do Not Repeat Struct Names in Fields**: Unless dictated by an external serialization schema, name the field `name` inside `ClientProfile` rather than `client_name`. When destructured into a standalone local variable where ambiguity could arise, bind the local variable as `client_name`.

### Parameter Grouping & Wire Compatibility

1. **Fold Excessive Parameters into Structs**: Functions with many parameters must group them into semantic structs.

   **Good ✅**: Group target descriptor, primary payload, execution context, and optional settings separately
   ```rust
   fn make_some_big_news(
       &self,
       target: &TargetDescriptor,
       request: Request,
       context: &Ctx,
       options: &Options,
   ) -> Result<Response, Error>;
   ```

   **Bad 🚫**: Long positional parameter lists that make reordering or adding options error-prone
   ```rust
   fn make_some_big_news(
       &self,
       target_id: &str,
       by: &str,
       content: &str,
       timestamp: &str,
       notify: &[&str],
       max_number: Option<usize>,
       timeout: Option<Duration>,
   ) -> Result<Response, Error>;
   ```

2. **Backward-Compatible Wire Schemas**: Reuse existing HTTP/wire response structs (`*Json`) whenever appropriate rather than proliferating duplicates. Any newly added field must be `Option<T>` (paired with `#[skip_serializing_none]`) so omitted values are elided on the wire without breaking older clients.

---

## 3. Core Design Patterns

### Accessor Pattern vs. Extension Traits

Under Rust's Orphan Rule—or even within a single crate when partitioning a large core type across domains—we often need to attach modular capabilities to a struct. **NEVER abuse one-to-one singleton Extension Traits (`XxxExt`) to bolt domain methods onto a concrete `struct` or `enum`**. Doing so pollutes flat method namespaces, risks cross-module name collisions, forces callers to import traits everywhere, and cannot carry module-scoped context.

Use the **Accessor (Contextual View) Pattern** when extending concrete types with modular or domain-specific operations:

1. **Cross-Crate Extension & Scoped Context Injection (Facade + Submodule Accessor)**

```rust
// Base type defined in a provider crate
pub struct MyRobotContext {
    // ...
}

// Consumer crate: encapsulate a module view that binds module-scoped parameters
pub struct RocketModuleAccessor<C> {
    pub rocket_parameters: Arc<RocketParameters>,
    pub context: C,
}

// Constrain C via Deref / DerefMut:
// Read-only methods automatically work for both &MyRobotContext and &mut MyRobotContext;
// mutating methods are restricted strictly to mutable borrows.
impl<C: Deref<Target = MyRobotContext>> RocketModuleAccessor<C> {
    pub fn fuel_level(&self) -> f64 {
        // ...
    }
}

impl<C: DerefMut<Target = MyRobotContext>> RocketModuleAccessor<C> {
    pub fn fly(&mut self) -> Result<(), FlyError> {
        // ...
    }
}

// Top-level composition layer: wrap in a facade providing chained entry points to submodules.
// ONLY the outermost composition facade may implement Deref / DerefMut to forward base methods;
// submodule accessors MUST NEVER Deref back into the underlying context.
pub struct MyRobotAccessor {
    inner: MyRobotContext,
}

impl MyRobotAccessor {
    pub fn rocket_module(&self, param: Arc<RocketParameters>) -> RocketModuleAccessor<&MyRobotContext> {
        RocketModuleAccessor { rocket_parameters: param, context: &self.inner }
    }

    pub fn rocket_module_mut(&mut self, param: Arc<RocketParameters>) -> RocketModuleAccessor<&mut MyRobotContext> {
        RocketModuleAccessor { rocket_parameters: param, context: &mut self.inner }
    }
}

pub struct AppContext {
    pub my_robot: MyRobotAccessor,
}

// Call sites require zero trait imports, gaining clean secondary namespaces and mutability isolation:
app_context.my_robot.rocket_module_mut(param.clone()).fly()?;
// Original base methods remain accessible through the top-level facade:
app_context.my_robot.recycle()?;
```

2. **Domain-Scoped Data Access (Secondary Namespaces)**

Within the same crate, add an inherent `impl` on `Repo` in the domain module returning the accessor; across crates, mount the entry point on the composition facade while keeping all domain queries as inherent methods on the accessor:

```rust
pub struct Repo {
    conn: DbConnectionPool,
}

// Defined in the `user` domain module (R can also be generic over a DB executor to support both pools and transactions)
pub struct UserDataAccessor<R> {
    repo: R,
}

impl<R: Borrow<Repo>> UserDataAccessor<R> {
    pub fn get_profile(&self, user_ident: UserIdent) -> Result<UserProfile, GetUserProfileError> {
        // ...
    }
}

// Secondary namespace prevents dumping dozens of domain queries onto Repo itself:
let profile = repo.user_data().get_profile(user_ident)?;
```

3. **Legitimate Boundaries & Naming for Extension Traits**

Reserve extension traits strictly for two infrastructure-level cases:
- **Extending a `trait` (never a concrete `struct`)**: e.g., `StreamExt: Stream` or `AsyncReadExt: AsyncRead` backed by a blanket implementation (`impl<T: BaseTrait + ?Sized> BaseTraitExt for T`), deriving stateless combinators from atomic trait methods or preserving `dyn` compatibility on the base trait.
- **Adding universal combinators to unmodifiable `std` primitives/containers**: e.g., `anyhow::Context` on `Result` / `Option` or `bstr::ByteSlice` on `[u8]` (rarely needed in application code). **Do not mechanically name such traits `XxxExt`**—name them after the capability or abstraction they confer (such as `Context` or `ByteSlice`).

### Typed Capabilities & Proof Tokens

Encode runtime invariants ("must run inside a transaction", "must commit before returning", "must pass authorization") directly into type signatures so the compiler enforces compliance:

1. **Hoist Capabilities to the Orchestration Layer & Pass Explicitly as Context**: When coordinating transactions or locks across multiple operations, never open hidden transactions inside low-level repository methods or rely on implicit task-local state. Acquire the transaction handle (capability token) in the business orchestration layer and pass it explicitly into repository accessors.
2. **Enforce Terminal Actions via Unforgeable Return Tokens (e.g., `Committed<T>`)**: When a workflow must commit a transaction (or flush an audit record) before succeeding, wrap the return type in a proof token whose constructor is restricted to the terminal operation:

```rust
// Private inner field: only DbTx::commit can construct this token; callers cannot forge it
pub struct Committed<T>(T);

impl DbTx<'_> {
    pub async fn commit<T>(self, value: T) -> Result<Committed<T>, DbError> {
        self.inner.commit().await?;
        Ok(Committed(value))
    }
}

// Return signature guarantees every Ok path consumes `tx` and commits—preventing silent rollback bugs
pub async fn transfer(repo: &Repo, req: TransferReq) -> Result<Committed<Receipt>, BizError> {
    let mut tx = repo.begin_tx().await?;
    repo.account_data(&mut tx).debit(req.from, req.amount).await?;
    repo.account_data(&mut tx).credit(req.to, req.amount).await?;
    let receipt = Receipt::new(/* ... */);
    Ok(tx.commit(receipt).await?)
}
```

### Typestate Pattern: Decoupling Complex State Flows

When a long procedural function accumulates phase-dependent `let mut Option<T>` locals or tangles normal progression, retry loops, and rollback branches, decompose the monolithic function using **Typed State Nodes (`Flow<S>`) + Transition Enums**. Linear protocol lifecycles (e.g., `Session<Unauthed>` → `Session<Authed>`) follow naturally as the single-branch special case:

1. **Isolate Phase Data & Branching Logic**: Model each phase as a distinct state type whose transition consumes `self` by value, destroying stale phase state at compile time. Confine complex branching decisions inside each state's transition method so the top-level driver collapses into a clean state topology.
2. **Payload-Bearing `state: S` Over `PhantomData + Option`**: Store phase-specific data directly in `state: S` (using zero-sized unit structs like `struct Idle;` for stateless phases instead of `PhantomData`), eliminating cross-phase `Option` unwrapping and resource leaks.
3. **Pragmatic Restraint**: Apply Typestate only when isolating multi-phase invariants, cyclic retries/rollbacks, or strict protocol ordering. Write simple, short sequential flows directly without splintering trivial functions into state structs.

```rust
// Phase-scoped payloads hold ONLY data valid at that node—eliminating scattered `let mut Option<T>` locals
pub struct Preparing { raw_input: RawPayload }
pub struct Executing { plan: ValidatedPlan, attempt: u8 }
pub struct Verifying { lease: ResourceLease, output: ExecOutput }
pub struct RollingBack { lease: ResourceLease, reason: FailureReason }

pub struct JobFlow<S> {
    ctx: SharedJobCtx,
    state: S,
}

// Multi-way transition edges reify complex jumps hidden inside monolithic functions
pub enum VerifyTransition {
    Passed(CompletedReceipt),
    Retry(JobFlow<Executing>),
    Abort(JobFlow<RollingBack>),
}

impl JobFlow<Verifying> {
    // Branching is localized; consuming `self` forces every exit to commit, release, or hand off `lease`
    pub async fn verify(self) -> VerifyTransition {
        match check_output(&self.state.output).await {
            CheckResult::Ok => VerifyTransition::Passed(self.state.lease.commit()),
            CheckResult::TransientErr(_) if self.can_retry() => {
                let (plan, next_attempt) = self.state.lease.release_for_retry();
                VerifyTransition::Retry(JobFlow {
                    ctx: self.ctx,
                    state: Executing { plan, attempt: next_attempt },
                })
            }
            CheckResult::Failed(reason) => VerifyTransition::Abort(JobFlow {
                ctx: self.ctx,
                state: RollingBack { lease: self.state.lease, reason },
            }),
        }
    }
}

// Top-level driver exposes the high-level state topology at a glance:
pub async fn run_job(ctx: SharedJobCtx, input: RawPayload) -> Result<CompletedReceipt, JobError> {
    let mut exec = JobFlow::new(ctx, input).prepare().await?;
    loop {
        let verifying = exec.execute().await?;
        match verifying.verify().await {
            VerifyTransition::Passed(receipt) => return Ok(receipt),
            VerifyTransition::Retry(next_exec) => exec = next_exec,
            VerifyTransition::Abort(rollback) => return Err(rollback.rollback().await),
        }
    }
}
```

### Polymorphism Dispatch Ladder

Do not reflexively reach for `Arc<dyn Service + Send + Sync>` out of OOP habit (which incurs heap allocation, vtable indirection, and breaks native `async fn in trait`, pressuring code back toward `async_trait`); likewise, do not let generic type parameters infect long-lived top-level containers. Choose dispatch mechanisms in order from lightest to heaviest:

1. **Closed, Finite Set → Prefer `enum` Dispatch**: When all implementations are known at compile time (e.g., storage backends, channel adapters, production vs. test double), wrap them in an `enum` for zero dynamic overhead, native async support, and exhaustive matching.
2. **Static Composition & Capability Reuse → Generics `T: Trait` at Call/Accessor Boundaries**: e.g., making `AccountDataAccessor<R>` accept both a connection pool and `&mut DbTx`. Keep generics localized to short-lived boundaries rather than infecting `AppContext`.
3. **Open Heterogeneous Collections or Type-Erasure Boundaries → Judicious `dyn Trait`**: Reserve trait objects for runtime-registered plugin collections (`Vec<Box<dyn Plugin>>`) or deliberate module boundaries where erasing deeply nested generic types materially simplifies compilation and ergonomics.

---

## 4. Async, Concurrency & Error Handling

### Native Async & Flat Control Flow

- Prefer native async patterns (`impl Future` or explicit `BoxFuture`); **do not** introduce `async_trait` without a clear, compelling justification.
- Write idiomatic Rust 2024 control flow to minimize nesting: use `let ... else` to keep the happy path unindented, loop return values, and early returns.
- Inside `select!` macros, map branches to a local `Event` enum variant first and handle business logic outside the `select!` block.

### Concurrent State Management

- **Use Synchronous Locks for Short Critical Sections; NEVER Hold Across `.await`**: Protect pure in-memory state with `std::sync::Mutex` (or `parking_lot`), complete reads/writes inside a tight lexical block so the guard drops immediately, and only then `.await`.
- **Prefer the Actor Model for Stateful Async Components**: Avoid passing `Arc<tokio::sync::Mutex<BigState>>` around while performing async I/O under lock. Spawn a dedicated background task that exclusively owns the state (driven lock-free via `loop` + `select!`) and expose a lightweight handle wrapping `mpsc::Sender<Command>` (carrying `oneshot::Sender` when replies are needed).

### Error Handling

- **Layered Error Types**: Define structured internal and domain errors with `thiserror::Error`. Reserve `anyhow::Error` for uncontrolled external boundaries (network calls, subprocess invocations) and top-level application wiring.
- **Document Error Conditions**: Public functions returning `Result` must include an `# Errors` doc section describing failure conditions.
- **Never Swallow Errors**: Every error must either be explicitly handled or propagated upward; never silently discard or implicitly conflate distinct error cases.
- **Ban Bare `unwrap()`**: Refactor control flow to avoid `unwrap()`. Where an invariant is statically guaranteed, use `expect("clear invariant justification")`.

---

## 5. Implementation Hygiene & Comments

### Trust Proven Code

- **Prefer Standard Library Combinators Over Manual Indexing**: For string manipulation, use `str::split`, `str::trim`, `str::strip_prefix`, etc., instead of manual byte-index slicing (e.g., write `s.strip_prefix("xxx")` rather than `s.starts_with("xxx").then_some(&s[3..])`).
- **Do Not Reinvent the Wheel**: When mature ecosystem crates already solve a problem, do not hand-roll a half-baked substitute. Inspect how established crates solve similar problems before building custom infrastructure.

### Governing Magic Values

Evaluate literal constants against four tiers before writing them inline:

1. **One-off Test Fixtures**: Values used once in a single test may be written inline without ceremony.
2. **Self-Evident Trivial Constants**: Universal invariants such as `0`, `1`, or `24` hours in a day may be written directly.
3. **Tunable Operational Parameters**: Values that may vary across environments or runtime deployments belong in configuration structs with sensible defaults.
4. **Fixed Domain/Protocol Constants**: Non-configurable literals carrying domain meaning must be extracted as named `const` or `static` items.

### High-Signal Comments

Comments transfer critical context that types and names alone cannot express:

1. **Concise & Selective**: Comment only non-obvious invariants, edge cases, or subtle trade-offs; never narrate what the code visibly does.
2. **Write for Future Maintainers, Not as a Changelog**: Explain *why the current code behaves as it does*, never the history of discarded attempts or private conversations invisible to future readers.
   - **Bad 🚫**: *"I tried approach A first, found a bug, so switched to B."* (A is gone; mentioning it is noise.)
   - **Bad 🚫**: *"Per points 1 and 3 from our chat, use B instead of A."* (Future maintainers cannot see your chat.)
   - **Good ✅**: *"See discussion in [#32](https://github.com/...)."* (Traceable public record.)
   - **Good ✅**: *"Workaround for upstream rate-limit burst behavior; can switch to batch endpoint once X lands."* (Clarifies a non-obvious compromise and future path.)
3. **Cite Authoritative Sources**: A single link to an RFC, specification, issue, or paper carries more weight than paragraphs of prose explanation.

---

## 6. Testing & Verification Workflow

### Test Organization & Boundaries

- **Placement & Granularity**: Place white-box unit tests in a dedicated `tests.rs` submodule file rather than mixing them into production source files; place black-box integration tests under top-level `tests/`. Align each test file with a cohesive domain or feature rather than scattering ad-hoc test files.
- **Test Observable Contracts, Not Implementation Details**: Write tests for core business rules, security/authorization boundaries, wire compatibility, and real bug regressions. Assert externally observable behavior rather than mirroring internal implementation steps, and avoid redundant coverage of identical contracts.
- **Parallel Test Isolation**: Tests run concurrently by default—never mutate process-global state (such as `std::env::set_var`) inside tests. Inject environment-derived configuration explicitly via parameters.

### Pre-Delivery Verification Loop

Writing code is not completing the task. Before finishing any code change, run and pass all checks in order:

1. `cargo clippy --workspace --all-targets -- -D warnings` (resolve all warnings)
2. `cargo fmt` (enforce standard formatting)
3. `cargo test` (run and pass affected unit and integration tests)
