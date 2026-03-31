# Harness-Core 架构审计报告 V1.0

**审计日期**: 2026-03-31
**审计对象**: harness-core (KKD-ANS v2.0)
**审计级别**: Staff/Principal Engineer — 全局穿透审计
**审计范围**: 核心防御有效性、机器通信接口质量、集成易用性、演进路线盲区

---

## Executive Summary（执行摘要）

**一句话评价：这是一个方向正确、但尚未经过对抗性验证的"工业级雏形"（Industrial Prototype），距离生产可用还有若干致命缺口。**

harness-core 的核心愿景——通过物理门禁约束 LLM Agent 的代码输出质量——在理念上是业界前沿的。微内核调度器 (`verify.sh`) + 配置驱动 (`harness.yaml`) + AST 纯度扫描 (`check_purity.py`) 的三角架构，方向正确且设计清晰。

然而，当前实现存在 **3 个致命漏洞** 和 **5 个设计缺陷**，使得一个有经验的 Agent（或恶意 Agent）可以在不触发任何告警的情况下绕过全部防线。项目当前处于"空城验证"状态——所有指标为绿，但被验证的对象是零代码（`src/` 下全部为空 `__init__.py`）。**100% 的测试覆盖率和 0 个 lint 问题，是在验证"虚无"。**

---

## Part 1: Critical Vulnerabilities（高危漏洞）

### CVE-H1: 静默旁路——Python 不可用时全部检查被跳过且报告"通过" [严重度: P0-致命]

**位置**: `.harness/verify.sh` 第 24-63 行

```bash
# verify.sh 第 24-63 行
declare -A CFG
while IFS='=' read -r k v; do
    [ -n "$k" ] && CFG["$k"]="$v"
done < <(python3 -c "
...
" "$CONFIG_FILE")
```

**漏洞描述**: `verify.sh` 使用 Bash 进程替换（Process Substitution `< <(...)`）调用 `python3` 解析 YAML。在 `set -euo pipefail` 下，**进程替换中的命令失败不会导致主脚本退出**。如果 `python3` 不可用（如最小化 Docker 镜像）或内联 Python 脚本本身出错：

1. `CFG` 关联数组为空
2. `PROJECT_TYPE="${CFG[project_type]:-}"` → 空字符串
3. `if [ "$PROJECT_TYPE" = "python" ]` → FALSE，跳过所有插件调度
4. 进入 `else` 分支，打印 "⚠ Unsupported project_type" 但**不退出**
5. 遥测生成跳过（因为也需要 python3），或在某些环境下生成空结果
6. 最终验证门检查 `$RESULT_DIR/*.exit` → **没有任何 .exit 文件**
7. `OVERALL_EXIT` 保持为 0 → **输出 "All checks passed! ✓"**
8. `auto_commit.sh` 执行 → **未经任何检查的代码被自动提交**

**攻击链**: Agent 只需破坏 Python 环境（例如 `rm -f $(which python3)`），即可绕过全部验证。

**修复建议**: 在 YAML 解析后立即检查 `CFG` 是否为空和 `PROJECT_TYPE` 是否有效，否则 `exit 1`。

```bash
if [ -z "${PROJECT_TYPE}" ]; then
    echo "FATAL: Failed to parse harness.yaml or project_type is empty"
    exit 1
fi
```

---

### CVE-H2: AST 扫描器无法检测动态导入——`importlib`、`__import__`、`exec` 完全绕过 [严重度: P0-致命]

**位置**: `.harness/plugins/architecture/check_purity.py` 第 77-88 行

```python
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        ...
    elif isinstance(node, ast.ImportFrom):
        ...
```

**漏洞描述**: `check_purity.py` **仅检查 `ast.Import` 和 `ast.ImportFrom` 节点**。以下所有方式可以在 `src/domain/` 中引入外部依赖而不被检测到：

```python
# 绕过方式 1: importlib（最常见的 LLM 生成模式）
import importlib
logger = importlib.import_module("src.infrastructure.logger")

# 绕过方式 2: 内置 __import__
db = __import__("src.infrastructure.database")

# 绕过方式 3: exec/eval
exec("from src.infrastructure.logger import Logger")

# 绕过方式 4: sys.modules 直接操作
import sys
infra = sys.modules.get("src.infrastructure")
```

注意：`importlib` 本身是 stdlib，但不在 `STDLIB_ALLOWLIST` 中，所以 `import importlib` 会被当作"外部依赖"拦截。然而，**一个聪明的 Agent 可以直接使用 `__import__`（内置函数，无需 import 任何模块）或 `exec()`（同样是内置函数）完全绕过**。

**影响**: 对于刻意或无意间使用动态导入模式的 LLM Agent，领域纯度防线完全失效。

**修复建议**: 在 AST 扫描中增加对 `ast.Call` 节点的检查，识别对 `importlib.import_module`、`__import__`、`exec`、`eval` 的调用：

```python
DANGEROUS_CALLS = frozenset({"__import__", "exec", "eval"})
DANGEROUS_ATTRS = frozenset({"import_module"})

for node in ast.walk(tree):
    if isinstance(node, ast.Call):
        if isinstance(node.func, ast.Name) and node.func.id in DANGEROUS_CALLS:
            violations.append(f"Forbidden builtin call: {node.func.id}()")
        elif isinstance(node.func, ast.Attribute) and node.func.attr in DANGEROUS_ATTRS:
            violations.append(f"Forbidden dynamic import: .{node.func.attr}()")
```

---

### CVE-H3: 相对导入中 `from .. import <name>` 完全绕过扫描器 [严重度: P1-高危]

**位置**: `.harness/plugins/architecture/check_purity.py` 第 83-87 行

```python
elif isinstance(node, ast.ImportFrom):
    if node.module:  # ← 当 node.module 为 None 时跳过检查
        violations.extend(
            _check_module(node.module, domain_dotted, forbidden_prefixes)
        )
```

**漏洞描述**: 对于 `from .. import infrastructure` 形式的相对导入：
- `node.module` = `None`（不是 `"infrastructure"`——`infrastructure` 在 `node.names` 中）
- `node.level` = 2

由于 `node.module is None`，`if node.module:` 判断为 False，**整条导入语句被完全跳过**。

在 `src/domain/subpackage/module.py` 中写入：
```python
from .. import infrastructure  # node.module=None, 完全绕过
infrastructure.database.connect()
```

这是一个合法的 Python 导入，会在运行时成功解析（因为 `src/domain/../infrastructure` = `src/infrastructure`），但 check_purity.py 完全看不到。

**修复建议**: 增加对 `node.level > 0` 且 `node.module is None` 的处理，检查 `node.names` 中的名称：

```python
elif isinstance(node, ast.ImportFrom):
    if node.level and node.level > 0:
        # 有相对导入前缀，需要检查
        if node.module:
            resolved = resolve_relative(filepath, domain_path, node.level, node.module)
            # 检查 resolved 是否越过 domain 边界
        else:
            # from .. import X — 检查是否跨层
            for alias in node.names:
                violations.append(
                    f"Relative import 'from {'.' * node.level} import {alias.name}' "
                    f"may cross layer boundary"
                )
    elif node.module:
        violations.extend(_check_module(node.module, domain_dotted, forbidden_prefixes))
```

---

### CVE-H4: auto_commit.sh 中 `git add -A` 盲目暂存一切 [严重度: P1-高危]

**位置**: `.harness/plugins/git/auto_commit.sh` 第 35 行

```bash
git add -A
```

**漏洞描述**: `git add -A` 会将工作目录中**所有**未跟踪和已修改的文件加入暂存区，包括但不限于：
- `.env` 文件（如果 `.gitignore` 遗漏）
- 临时调试文件
- Agent 生成的中间产物
- 敏感的密钥或凭证文件

更关键的是，在 Submodule 场景下，如果宿主项目不小心在 `.harness/` 目录下放了文件，也会被提交。

**修复建议**: 改用显式暂存策略：

```bash
git add src/ tests/ docs/ harness.yaml telemetry.json AGENTS.md
```

或至少增加一个确认步骤/配置白名单。

---

## Part 2: Design Flaws（设计缺陷）

### DF-1: YAML 解析器是一个脆弱的手工实现——内联注释导致静默功能失效

**位置**: `.harness/verify.sh` 第 26-63 行（内嵌 Python YAML 解析器）

**问题**: 手写的 YAML 解析器不支持：

| 特性 | 是否支持 | 后果 |
|------|---------|------|
| 内联注释（`enabled: true # 注释`）| ✗ | `val = "true # 注释"` → 字符串比较失败 → **插件静默禁用** |
| Tab 缩进 | ✗ | 缩进计算错误 → 配置丢失 |
| YAML 锚点/引用 | ✗ | 功能受限 |
| 多行字符串 | ✗ | 功能受限 |
| 数组值 | ✗ | 无法支持多值配置 |

**内联注释的具体攻击路径**: 如果 `harness.yaml` 中写 `enabled: true  # enable linting`，解析结果 `val = "true  # enable linting"`，与 `"true"` 不等，linter 插件被跳过。**这不需要恶意意图，只需要一个正常的 YAML 编辑习惯即可触发。**

**建议**: 使用 `PyYAML`（或 `ruamel.yaml`），或者至少在解析时裁剪内联注释：`val = val.split('#')[0].strip()`。更好的方案是将 YAML 解析独立为一个插件，使其可测试。

---

### DF-2: 工具链版本未锁定——验证结果不可复现

**位置**: `.harness/plugins/python/setup_env.sh` 第 39 行和第 45 行

```bash
uv pip install ruff mypy pytest pytest-cov      # 无版本约束
pip install --quiet ruff mypy pytest pytest-cov  # 无版本约束
```

**问题**: 每次运行 `setup_env.sh` 都会安装这些工具的**最新版本**。ruff 和 mypy 的版本升级经常引入新的规则或破坏性变更。今天通过的代码，明天可能因为 ruff 更新了规则而失败。

**后果**: Law 2（Zero-Inference Verification）的"可复现"承诺无法兑现。

**建议**: 添加版本锁定：
```bash
uv pip install "ruff==0.9.x" "mypy==1.15.x" "pytest>=8.0,<9" "pytest-cov>=6.0,<7"
```
或提供一个 `requirements-toolchain.txt`。

---

### DF-3: 覆盖率阈值硬编码——违反 Law 3（Configuration）

**位置**: `.harness/plugins/python/run_tests.sh` 第 77 行

```python
threshold = 80  # 硬编码在 Python 内联脚本中
```

**问题**: `harness.yaml` 声称是"the single source of truth"（Law 3），但覆盖率阈值 80% 被硬编码在 `run_tests.sh` 的内嵌 Python 脚本中，无法通过配置文件调整。这是框架自身对 Law 3 的违反。

**建议**: 从 `harness.yaml` 读取阈值，例如：
```yaml
modules:
  tests:
    enabled: true
    coverage_threshold: 80
```

并通过环境变量传入插件脚本。

---

### DF-4: 插件无超时机制——任意插件挂起导致整个流水线死锁

**位置**: `.harness/verify.sh` 第 94-126 行（`run_plugin` 函数）

```bash
run_plugin() {
    ...
    if [[ "$script" == *.py ]]; then
        python3 "$script" "$result_file" 2>&1
    else
        bash "$script" "$result_file" 2>&1
    fi
    ...
}
```

**问题**: 插件执行没有任何超时限制。如果 pytest 进入死循环、mypy 在大型项目上卡住、或者 `pip install` 在断网环境下等待 DNS 解析，`verify.sh` 会**永久挂起**。在 CI/CD 环境中，这意味着一个 Runner 被无限占用。

**建议**: 使用 `timeout` 命令包裹插件执行：
```bash
timeout "${PLUGIN_TIMEOUT:-300}" bash "$script" "$result_file" 2>&1
```

---

### DF-5: Submodule 集成路径完全缺失——核心愿景无法落地

**问题**: README 和 AGENTS.md 的核心叙事是"作为 Git Submodule 嵌入到任何业务项目中"，但：

- 没有 `install.sh` 或 `bootstrap.sh` 用于 Submodule 初始化
- 没有宿主项目（Host Project）的模板或示例
- `PROJECT_ROOT` 在所有脚本中通过**相对路径计算**（`$SCRIPT_DIR/..`），当 `.harness/` 作为 Submodule 位于 `vendor/harness-core/.harness/` 时，所有路径解析都会指向错误的位置
- `check_purity.py` 硬编码 `project_root / "src" / "domain"`——当宿主项目的源码不在 `src/domain/` 时完全失效
- 没有说明宿主项目如何覆盖/扩展 `harness.yaml`

**这意味着当前框架的核心 selling point（Submodule 嵌入）在实现上是完全不可用的。**

---

## Part 3: Additional Findings（其他发现）

### AF-1: AGENTS.md 中存在 LLM 逻辑死循环风险

**位置**: `AGENTS.md` Law 2 / `docs/ARCHITECTURE.md` Law 2

> "verify.sh is the sole judge. Run it before reporting done. If it fails, self-fix."
> "Never ask for help on a red build."

**问题**: 如果 `verify.sh` 本身有 bug（如 CVE-H1 中描述的），或者某个检查因环境问题持续失败（如 mypy 在某些平台上有已知 bug），Agent 会进入一个无限的 "fix → verify → fail → fix" 循环。没有重试上限、没有升级机制、没有"熔断"逻辑。

**建议**: 添加明确的退出条件：
```
If verify.sh fails more than 3 consecutive times on the same issue,
stop and report the situation in progress.txt with full error context.
```

### AF-2: 遥测数据覆盖而非追加——无法做趋势分析

**位置**: `.harness/verify.sh` 第 232 行

```python
with open("telemetry.json", "w") as f:  # 覆盖写入
```

每次运行都覆盖 `telemetry.json`，历史数据丢失。虽然 `progress.txt` 有追加记录，但只记录了时间戳和 Task ID，没有实际的指标数据。Law 5（Telemetry & Observability）的"可观测性"承诺打了折扣。

### AF-3: `src/` 下无任何业务代码——当前验证的是"虚无"

当前项目的全部 `src/` 文件都是空的 `__init__.py`。`test_skeleton.py` 唯一的测试是 `def test_skeleton(): pass`。这意味着：

- 100% 的测试覆盖率和 0 个 lint 问题是**空集上的真命题**
- 所有 5 条 Architecture Laws 从未在真实代码上得到验证
- 框架尚处于"理论设计"阶段，缺少 dogfooding（自我验证）

### AF-4: 跨平台兼容性为零

- 所有 shell 脚本假设 Bash 4.0+（`declare -A` 关联数组）
- 未考虑 macOS 默认 bash 3.x（除非用户安装了 brew bash）
- Windows（即使通过 Git Bash/WSL）路径分隔符差异未处理
- `mktemp` 的 `-d` 参数在不同平台上行为一致，但 `trap` 清理在某些 shell 中不可靠

### AF-5: Python YAML 解析器运行在系统 Python 上

`verify.sh` 中的 YAML 解析用的是 `python3 -c "..."` ——**这是系统 Python，不是 .venv 中的 Python**。因为此时 .venv 还没有被创建。这意味着：

- 如果系统没有 `python3`，整个流程静默失败（CVE-H1）
- 如果系统 `python3` 版本过低（如 3.5），某些语法可能不支持
- 整个"强制使用 .venv"的承诺在自身的调度层就已经被打破

---

## Part 4: Next Steps（战略建议）

### 优先级 #1: 修复验证旁路漏洞（CVE-H1 + CVE-H2）

这是最紧迫的问题。一个没有有效门禁的治理框架等于没有门禁。

**具体行动**:
1. 在 `verify.sh` 的 YAML 解析之后添加强制检查：`PROJECT_TYPE` 为空或 `CFG` 为空时立即 `exit 1`
2. 在最终验证门处添加：如果没有任何 `.exit` 文件生成，视为失败而非通过
3. 在 `check_purity.py` 中添加对 `__import__`、`exec`、`eval` 调用的 AST 检测
4. 在 `check_purity.py` 中处理 `node.module is None` 且 `node.level > 0` 的相对导入情况

**验证方式**: 编写对抗性测试——创建包含动态导入和相对导入的测试文件，确认扫描器能检测到它们。

### 优先级 #2: 实现真正的 Submodule 集成协议

这是框架的核心价值主张，目前完全没有实现。

**具体行动**:
1. 所有脚本中的 `PROJECT_ROOT` 改为可配置（通过环境变量或 `harness.yaml` 中的字段），而非硬编码的相对路径计算
2. `check_purity.py` 的 `domain_path` 改为从配置读取，而非硬编码 `src/domain`
3. 创建 `install.sh`：用于将 harness-core 作为 submodule 引入宿主项目，自动设置 symlink 或 wrapper script
4. 创建一个最小的 `examples/` 目录，包含一个宿主项目示例
5. 在 AGENTS.md 中增加 "Submodule Integration Guide" 章节

### 优先级 #3: 用真实代码 Dogfooding 验证五条 Architecture Laws

当前框架从未约束过一行真正的业务代码。需要：

**具体行动**:
1. 在 `src/domain/` 中实现至少一个有意义的领域模型（例如：Task 实体、Verification Result 值对象——框架本身的领域模型）
2. 在 `src/infrastructure/` 中实现至少一个适配器（例如：文件系统遥测写入器）
3. 编写充分的单元测试，使覆盖率指标有真实含义
4. 故意注入一些违规代码（如在 domain 中 import os），验证 check_purity.py 确实能拦截
5. 尝试上述审计中的所有绕过手段，形成回归测试套件

---

## Appendix: 漏洞速查矩阵

| ID | 类型 | 严重度 | 位置 | 一句话描述 |
|----|------|--------|------|-----------|
| CVE-H1 | 逻辑漏洞 | P0-致命 | verify.sh:24-63 | Python 不可用时所有检查静默跳过并报告通过 |
| CVE-H2 | 绕过漏洞 | P0-致命 | check_purity.py:77-88 | `__import__`/`exec`/`eval` 动态导入绕过 AST 扫描 |
| CVE-H3 | 绕过漏洞 | P1-高危 | check_purity.py:83-87 | `from .. import X` 相对导入绕过扫描 |
| CVE-H4 | 安全风险 | P1-高危 | auto_commit.sh:35 | `git add -A` 盲目暂存可能包含敏感文件 |
| DF-1 | 设计缺陷 | P2-中危 | verify.sh:26-63 | 手工 YAML 解析器不支持内联注释，导致插件静默禁用 |
| DF-2 | 设计缺陷 | P2-中危 | setup_env.sh:39,45 | 工具链版本未锁定，结果不可复现 |
| DF-3 | 设计缺陷 | P2-中危 | run_tests.sh:77 | 覆盖率阈值硬编码，违反 Law 3 |
| DF-4 | 设计缺陷 | P2-中危 | verify.sh:94-126 | 插件执行无超时，可导致流水线死锁 |
| DF-5 | 架构缺失 | P1-高危 | 全局 | Submodule 集成路径完全缺失 |
| AF-1 | 接口缺陷 | P2-中危 | AGENTS.md | LLM 无退出条件的无限循环风险 |
| AF-2 | 设计缺陷 | P3-低危 | verify.sh:232 | 遥测数据覆盖非追加 |
| AF-3 | 验证空洞 | P2-中危 | src/ | 零业务代码，验证指标无实际意义 |
| AF-4 | 兼容性 | P3-低危 | 全部 shell 脚本 | 跨平台兼容性为零 |
| AF-5 | 设计矛盾 | P2-中危 | verify.sh:26 | YAML 解析绕过 .venv 使用系统 Python |

---

**审计结论**: harness-core 的架构思路是正确的——用物理门禁约束 Agent 行为的方向值得肯定。但当前实现尚处于"概念验证"阶段，核心防线存在可绕过的漏洞，核心卖点（Submodule 集成）未实现，且从未在真实代码上验证过自身规则。建议在修复上述 P0/P1 漏洞后，优先进行 dogfooding——让框架治理自身的代码开发过程——这将是验证其设计有效性的最佳方式。

---

*报告结束。审计人：AI Architecture Auditor | 审计标准：OWASP Secure SDLC + Domain-Driven Design + Agent Safety*
