# Rust 编码规范

以下规范仅限定项目手写源码，不针对自动生成的代码。

---

## 0. 总纲：良质（Quality）、完形（Gestalt）与“势”

**编码本质上是一门复杂系统工程，必须从整体性的高度去把握，而非孤立代码片段的机械拼装。**我们常说的“代码质量”，在更本源的意义上正是**良质（Quality）**——它无法被单一的局部指标或一句话的定义所穷尽，而需要从不同侧面去窥见：它是超越局部之和的**完形（Gestalt）**，是诸要素在相对关系与张力中构成的**“势”**，也是工程构建中的**艺术与审美**。

面对复杂系统时，始终坚持整体性的视野，拒绝“管中窥豹”式的局部修补：

- **整体先于局部**：任何结构体、函数或模块的意义都不孤立存在于其内部，而在于它与周围事物的关系之中。落笔修改前，先退后一步感知所在模块的整体格局与上下文脉络，让新代码顺应原有的肌理自然生长，不留突兀的拼凑痕迹。
- **在关系中安放形态**：概念上平级的模块与对偶的操作，在结构与命名上应当同构对称；概念上从属的实现细节，应当收拢下沉、对外隐蔽；紧密耦合的状态与行为就近内聚，正交的职责拉开边界与留白。
- **以审美直觉侦测失衡**：丑陋、拧巴、充斥特判与透传补丁的代码，往往不只是表层的文风瑕疵，而是局部破坏了整体完形与“势”的警报。当新需求塞进现有结构显得别扭刺眼时，严禁为了贪图局部最小改动而强行硬拧——应回到整体视角重新理顺概念边界，重塑通透的格局后再落笔实现。

---

## 1. 模块架构与代码组织

### 子模块与资源目录

子模块统一采用“同名入口文件 + 同名目录”组织，**禁止**使用 `mod.rs`。模块所需的硬编码静态资源（如 JSON 模板、长文本）统一放在该模块下的 `assets/` 目录，白箱测试独立放在 `tests.rs`：

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

### 目录结构映射概念层级

从领域概念与职责层级出发组织树状模块，同级文件必须在架构上具备并列关系，禁止将不同抽象层级的实现平铺在同一目录下。

**正例 ✅**：按职责分层收拢实现与模型

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

**反例 🚫**：缺少层级，从属实现与核心概念平铺混杂

```text
🦀 payment.rs
  +-- 🦀 <impl_a>.rs
  +-- 🦀 <impl_b>.rs
  +-- 🦀 audit.rs
  +-- 🦀 bill.rs
  +-- 🦀 credits.rs
  +-- 🧪 tests.rs
```

### 深模块与窄接口

维护者与 AI 的注意力都是稀缺资源。模块设计应**渐进式披露细节**，严格控制每一层的认知宽度：

- **窄接口（默认私有，刻意暴露）**：字段、辅助函数与内部结构默认私有或 `pub(crate)`，对外仅暴露表达高层语义的最小 API 面，不将底层实现机制泄漏到模块签名中。
- **深模块（拒绝无实质收益的浅层包装）**：将过长函数拆分为聚焦、单一职责的辅助函数；但**不要为只被调用一次且无独立业务语义的几行代码硬抽出薄皮透传函数**——多一层跳转的间接成本，必须由“真正屏蔽掉的复杂度”或“多处复用”来买单。
- **打包导出**：相对独立的子模块应在模块入口统一重导出核心接口；调用方按需聚合引入，减少内部文件调整带来的跨模块导入噪音与 Git 变更扩散。

---

## 2. 类型语义与接口设计

我们从可维护性与 AI 友好性的高度出发，要求代码具备清晰的**语义正确性**——类型与签名本身就是最准确的文档。

### 用类型消除非法状态

1. **互斥状态用带载荷的 `enum` 绑定**：禁止在结构体中用状态字段配合多个平行的 `Option` 字段拼凑阶段数据（如同时存放 `status`、`result: Option<T>`、`error: Option<E>`），应直接定义为 `enum TaskState { Pending, Running { started_at: Instant }, Done(T), Failed(E) }`。`match` 时尽量穷举变体，避免滥用 `_` 通配臂，确保新增变体时由编译器提醒所有受影响分支。
2. **边界解析（Parse, Don't Validate）与 Newtype**：在系统入口通过 `TryFrom` / `FromStr` 一次性将原始输入解析为受控的 `Newtype`（如 `UserId`、`Email`）或自描述 `enum`，进入核心域后直接信任类型不变量，不在内部反复做防御性校验。同时避免在函数签名中使用意图不明的 `bool` 或裸 `Option` 位置参数（拒绝 `foo(false, None)` 这类无法自解释的调用点）。
3. **不要滥用 Tuple**：禁止滥用匿名 Tuple 作为函数的参数或返回值，应定义具名结构体表达明确的字段语义。

### 正确使用标准类型转换

积极使用 Rust 标准库的类型转换基础设施：`From` / `Into`、`TryFrom` / `TryInto`、`FromStr` / `Display`，避免自创非标准的转换方法名。对于泛型约束下不可能失败的特例，错误关联类型应使用 Rust `1.100` 稳定的 never 类型 `!`。

### 考究命名与消除冗余信息

函数与类型的命名应直接体现其职责，同时结合上下文消除冗余前缀：

1. **善用模块命名空间**：已定义在 `system` 模块下的请求结构应直接命名为 `Request`（通过 `system::Request` 引用），而非冗余的 `SystemRequest`。例外：若多个子模块模型会被统一重导出到扁平的 `model` 层，调用方失去了子模块路径语境，此时保留领域前缀（如 `BillingRecord`）是有意义的。
2. **结构体字段不重复类型名**：除非受外部序列化协议约束，`ClientProfile` 内部的客户端名称字段应直接命名为 `name` 而非 `client_name`；当将其解构为独立局部变量且可能与其他名称混淆时，局部变量再命名为 `client_name`。

### 收敛函数参数与协议兼容

1. **折叠多参数函数**：参数较多的函数应按职责折叠为具名结构体。

   **正例 ✅**：将目标描述符、主请求、上下文、可选项分别归组打包
   ```rust
   fn make_some_big_news(
       &self,
       target: &TargetDescriptor,
       request: Request,
       context: &Ctx,
       options: &Options,
   ) -> Result<Response, Error>;
   ```

   **反例 🚫**：平铺大量参数，无论调整顺序还是新增配置都是维护灾难
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

2. **外部协议与响应向后兼容**：HTTP 响应等序列化结构（如 `*Json`）优先复用现有定义，非必要不新建。演进时新增字段一律使用 `Option` 类型（配合 `#[skip_serializing_none]`），未填充时省略输出，避免破坏旧版客户端。

---

## 3. 核心设计模式

### 访问器模式（Accessor）与拓展 Trait 的取舍

受孤儿原则（Orphan Rule）限制，我们有时需要在外部包声明的结构体上拓展能力；即便在同一个包内，也需要按领域拆分大型结构的方法。**禁止为了给具体结构体（`struct` / `enum`）挂载业务方法而滥用“一配一”的拓展 Trait（`XxxExt`）**——这会导致命名空间扁平化污染、跨模块同名冲突、调用方被迫到处显式 `use` Trait，且无法携带模块级的局部上下文参数。

对具体结构拓展业务模块或领域能力时，优先使用**访问器模式（Accessor / Contextual View）**：

1. **跨包拓展与携带局部上下文（组装门面 + 子模块访问器）**

```rust
// provider crate 中的基础结构
pub struct MyRobotContext {
    // ...
}

// consumer crate：按功能模块封装访问器视图，同时绑定模块所需的局部参数
pub struct RocketModuleAccessor<C> {
    pub rocket_parameters: Arc<RocketParameters>,
    pub context: C,
}

// 用 Deref / DerefMut 约束 C：
// 只读方法对 &MyRobotContext 和 &mut MyRobotContext 同时生效；可变方法仅对可变借用开放
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

// 顶层组装层：封装门面（Facade）提供到各子模块的链式入口
// 仅限最外层组装门面可实现 Deref / DerefMut 透传原有基础方法；子模块访问器严禁 Deref 回底层结构
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

// 调用处无需额外导入任何 Trait，具备清晰的二级命名空间与读写隔离：
app_context.my_robot.rocket_module_mut(param.clone()).fly()?;
// 原有基础方法通过顶层门面透传调用：
app_context.my_robot.recycle()?;
```

2. **按业务域隔离数据访问（二级命名空间）**

同包内可直接在对应子模块为 `Repo` 编写固有 `impl` 返回访问器；跨包则在组装层挂载入口，将具体查询方法收拢在各领域的访问器固有实现上：

```rust
pub struct Repo {
    conn: DbConnectionPool,
}

// 在 user 领域模块中定义访问器视图（也可将 R 泛型化为数据库执行器以同时兼容连接池与事务）
pub struct UserDataAccessor<R> {
    repo: R,
}

impl<R: Borrow<Repo>> UserDataAccessor<R> {
    pub fn get_profile(&self, user_ident: UserIdent) -> Result<UserProfile, GetUserProfileError> {
        // ...
    }
}

// 通过二级命名空间调用，避免把所有领域的数十个查询方法平铺在 Repo 本体上：
let profile = repo.user_data().get_profile(user_ident)?;
```

3. **拓展 Trait 的合理边界与命名**

仅在以下两类基础设施级场景中使用拓展 Trait：
- **真正拓展一个 `trait`（而非具体 `struct`）**：例如 `StreamExt: Stream`、`AsyncReadExt: AsyncRead`，配合一揽子泛型实现（`impl<T: BaseTrait + ?Sized> BaseTraitExt for T`），用于基于原子接口派生无状态的通用组合子，或保护基础 Trait 的 `dyn` 对象安全。
- **为无法修改的标准库/底层原语补充通用算子**：例如为 `Result` / `Option` 补充错误上下文的 `anyhow::Context`，或为 `[u8]` 补充字节串操作的 `bstr::ByteSlice`（通常属于底层通用库范畴，业务代码极少需要自建）。此类 Trait **不要机械命名为 `XxxExt`**，而应直接以所赋予的核心能力或概念命名（如 `Context`、`ByteSlice`）。

### 类型化能力与结果凭据

将运行时的隐式约定（如“必须在同一事务中执行”、“返回前必须提交事务”、“必须已通过鉴权”）编码进类型签名，由编译器强制监督履约：

1. **能力上交编排层，作为 Context 显式回传**：跨多个操作协调事务或锁时，禁止在底层 Repo 方法内暗自开启事务或依赖隐式上下文。应由业务编排层显式申请事务句柄（能力令牌），再通过参数或访问器显式回传给数据层执行。
2. **用受控返回类型约束终结动作（如 `Committed<T>`）**：若业务函数要求成功返回前必须完成事务提交（或审计落盘），可在返回类型上包裹外部无法伪造的凭据类型：

```rust
// 字段私有，仅允许事务句柄在 commit 成功后构造，业务层无法伪造
pub struct Committed<T>(T);

impl DbTx<'_> {
    pub async fn commit<T>(self, value: T) -> Result<Committed<T>, DbError> {
        self.inner.commit().await?;
        Ok(Committed(value))
    }
}

// 返回类型强制担保：任何 Ok 路径都必须消费 tx 并完成提交，杜绝漏调 commit 导致的静默回滚
pub async fn transfer(repo: &Repo, req: TransferReq) -> Result<Committed<Receipt>, BizError> {
    let mut tx = repo.begin_tx().await?;
    repo.account_data(&mut tx).debit(req.from, req.amount).await?;
    repo.account_data(&mut tx).credit(req.to, req.amount).await?;
    let receipt = Receipt::new(/* ... */);
    Ok(tx.commit(receipt).await?)
}
```

### 类型状态模式（Typestate）：解耦复杂状态流转

当单个长流程函数开始堆积多个随阶段变化的 `let mut Option<T>` 局部变量，或交织着正常推进、重试回环、异常回滚等复杂分支时，应采用**“类型状态节点（`Flow<S>`）+ 跃迁枚举边”**拆解巨石函数；单向协议生命周期（如连接 `Session<Unauthed>` → `Session<Authed>`）同理作为其无分支特例处理：

1. **隔离阶段状态与分支判断**：每个阶段各自建模为独立状态类型，跃迁方法按值消费 `self` 在编译期销毁旧状态，将复杂的分支判断收敛在当前节点内，使顶层驱动函数退化为清晰的状态流转拓扑。
2. **实体状态载荷优于 `PhantomData + Option`**：直接用 `state: S` 字段持有该阶段专属数据（无载荷阶段用零大小的单元结构体 `struct Idle;`，无需 `PhantomData`），彻底消除跨阶段 `Option` 判空与资源漏释放。
3. **克制使用边界**：仅在存在跨阶段状态隔离、多路回环/回滚流转或严格的调用次序契约时使用；简单的线性短流程或无状态纠缠的普通条件分支直接顺序编写，不为套模式而拆碎简单函数。

```rust
// 各阶段专属载荷：仅持有当前节点合法的数据，消灭大函数顶部的十几个 `let mut Option<T>`
pub struct Preparing { raw_input: RawPayload }
pub struct Executing { plan: ValidatedPlan, attempt: u8 }
pub struct Verifying { lease: ResourceLease, output: ExecOutput }
pub struct RollingBack { lease: ResourceLease, reason: FailureReason }

pub struct JobFlow<S> {
    ctx: SharedJobCtx,
    state: S,
}

// 多路分支出口：将深埋在巨石函数里的复杂跳转显式建模为目标状态枚举
pub enum VerifyTransition {
    Passed(CompletedReceipt),
    Retry(JobFlow<Executing>),
    Abort(JobFlow<RollingBack>),
}

impl JobFlow<Verifying> {
    // 分支逻辑收敛在当前状态内；按值消费 self 强制每个出口妥善提交、归还或移交 lease
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

// 顶层函数只保留清晰的状态拓扑全景，局部节点细节按需渐进式展开：
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

### 多态分发的选型阶梯

避免惯性使用 `Arc<dyn Service + Send + Sync>` 照搬传统 OOP 接口注入（不仅带来额外堆分配与虚表跳转，还会破坏原生 `async fn in trait`，倒逼引入不必要的 `async_trait`）；同时也不要将过多泛型参数传染并固化到顶层长期存活的容器结构上。按以下优先级由轻到重选型：

1. **封闭有限集合 → 优先用 `enum` 分发**：当实现种类在编译期已知（如固定几种渠道适配器、存储后端、真实实现与测试替身），直接用枚举包装各实现，零动态开销、天然支持原生异步与穷尽匹配。
2. **静态组合与能力复用 → 在函数或访问器边界用泛型 `T: Trait`**：例如让 `AccountDataAccessor<R>` 同时兼容连接池与 `&mut DbTx`；尽量将泛型收敛在短期调用边界，不向顶层 `AppContext` 无限传染。
3. **开放异构集合或切断泛型传染 → 审慎使用 `dyn Trait`**：仅在需要存放运行期动态组装的异构对象（如 `Vec<Box<dyn Plugin>>`），或确需在模块边界抹平极度复杂的泛型签名时使用。

---

## 4. 异步、并发与错误处理

### 异步与扁平控制流

- 优先使用原生异步模式（`impl Future` 或 `BoxFuture`），除非有充分且明确的理由，否则**不要**引入 `async_trait`。
- 始终采用 Rust 2024 惯用写法减少嵌套：善用 `let ... else` 保持主干路径扁平、善用循环返回值与提前返回。
- 在 `select!` 分支中先将结果收敛为本地 `Event` 枚举变体，在 `select!` 结束之后再统一处理业务逻辑。

### 并发状态管理

- **短临界区用同步锁，严禁跨 `.await` 持锁**：纯内存状态同步使用 `std::sync::Mutex`（或 `parking_lot`），在独立作用域块内读写完毕并立即释放锁后，再去执行 `.await`。
- **复杂异步有状态组件优先采用 Actor 模式**：避免将 `Arc<tokio::sync::Mutex<BigState>>` 到处传递并在持锁期间夹杂异步 I/O。优先由单个后台 Task 独占状态（内部通过 `loop` + `select!` 无锁驱动），对外仅暴露持有 `mpsc::Sender<Command>`（需要返回值时在命令中携带 `oneshot::Sender`）的轻量 Handle。

### 错误处理

- **内外错误分层**：内部模块与领域错误使用 `thiserror::Error` 声明结构化枚举；`anyhow::Error` 仅用于不受控的外部系统边界（如网络请求、外部进程调用）或顶层应用编排。
- **文档化错误契约**：公开的返回 `Result` 的函数，须在文档注释中包含 `# Errors` 小节说明触发失败的条件。
- **严禁忽略错误**：错误要么被明确处理，要么向上传播，避免隐式合并或静默吞掉错误。
- **禁用裸 `unwrap()`**：应通过重构控制流消除 `unwrap()`；确有静态不变量保障而必须断言时，使用 `expect("清晰的不变量理由")` 替代。

---

## 5. 实现细节与注释规范

### 相信经过验证的代码

- **优先使用标准库高阶方法**：例如字符串处理优先使用 `str::split`、`str::trim`、`str::strip_prefix` 等方法，而非手动计算字节下标切片（如用 `s.strip_prefix("xxx")` 代替 `s.starts_with("xxx").then_some(&s[3..])`，更健壮且意图自明）。
- **避免重复造轮子**：社区已有成熟实现的问题，不要自己手写半成品。若不确定选型，先考察解决同类问题的流行库依赖了什么方案，或评估能否直接复用其实现。

### 治理魔法值

写入字面量常量前，按以下四类情况分流处理：

1. **单次测试数据**：仅在单个测试中临时使用一次的值，直接书写即可，无需过度封装。
2. **显而易见的平凡常量**：如 `0`、`1`、一天 `24` 小时等恒定常识值，可直接写入。
3. **潜在可调参数**：未来可能需要按环境或运行期调整的值，应归入配置结构并提供合理的默认值。
4. **固定业务/协议常量**：不可配置但具有特定领域含义的硬编码值，必须提取为具名的 `const` 或 `static`。

### 高信噪比注释

注释用于在维护者之间传递代码本身无法表达的关键上下文，应保持克制、准确：

1. **简洁克制**：仅为非显而易见的逻辑、边界条件或安全不变量添加注释，拒绝复述代码表面行为的废话注释。
2. **面向未来，而非记录修改流水账**：注释应向未来的维护者解释“当前代码为什么这样工作”，而不是回忆过去的试错过程或引用外部不可见的私下讨论。
   - **反例 🚫**：“我本来做了 A，发现不对改成了 B。”（A 已被删除，提及它是纯噪音）
   - **反例 🚫**：“这里不要做 A，基于讨论的第 1、3 点改用 B。”（后来的维护者看不到当时的对话）
   - **正例 ✅**：“参见 [#32](https://github.com/...) 的讨论。”（指向可追溯的公开上下文）
   - **正例 ✅**：“此处为绕过上游限流的临时妥协，后续可改为批量接口……”（指出非常规妥协与演进方向）
3. **引用权威来源**：解释协议细节、算法或特殊行为时，附上一条权威链接（RFC、官方文档、Issue、论文）的信息量胜过千行自说自话的解释。

---

## 6. 测试与交付自检

### 测试组织与边界

- **目录与粒度**：白箱测试统一放在对应模块的 `tests.rs` 中，不要与业务代码混在同一文件；集成黑箱测试放在仓库根目录 `tests/` 下。每个测试文件对应一个明确的领域或功能模块，不随意新建零散测试文件。
- **测试可观察契约，而非实现细节**：只为确需保障的核心逻辑、权限安全边界、协议兼容与真实缺陷回归编写测试。优先断言外部可观察的行为结果，避免照抄内部实现做脆弱断言，相同契约不重复覆盖。
- **并行测试隔离**：测试默认并发运行，禁止在测试中修改进程级全局状态（如 `std::env::set_var`），环境相关依赖应通过参数或配置结构显式注入。

### 交付前自检闭环

完成代码修改后，必须依次执行并通过以下检查，写完代码不等于完成任务：

1. `cargo clippy --workspace --all-targets -- -D warnings`（清理全部警告）
2. `cargo fmt`（保持标准格式）
3. `cargo test`（运行受影响模块与相关集成测试并确认通过）
