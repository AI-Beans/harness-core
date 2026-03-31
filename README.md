# harness-core

> Agent Governance Framework — 让 AI Agent 在流水线上当标准工人，而不是法外狂徒。

## 它是什么

harness-core 是一个**微内核式验证框架**，通过配置文件 (`harness.yaml`)、物理门禁 (`verify.sh`) 和领域纯度扫描 (`check_purity.py`)，对 LLM Agent 的代码输出进行强制性的架构约束和质量拦截。

```
                    harness.yaml
                   (配置中心)
                         │
                         ▼
                    verify.sh
                   (调度器)
          ┌────────┼────────┼────────┐
          ▼        ▼        ▼        ▼
       ruff      mypy    pytest   check_purity
       (lint)   (types)  (test)   (domain AST)
```

## 30 秒上手

### 方式一：直接 Clone（独立项目）

```bash
git clone https://github.com/AI-Beans/harness-core.git my-project
cd my-project
bash init.sh
```

### 方式二：作为 Git Submodule（嵌入现有项目）

```bash
cd your-project
git submodule add https://github.com/AI-Beans/harness-core.git .harness-core
bash .harness-core/init.sh
```

`init.sh` 会自动：
- 创建 `src/{domain,infrastructure,config}/`、`tests/`、`docs/` 目录结构
- 生成 `__init__.py` 文件
- 复制 `harness.yaml`、`AGENTS.md` 等配置到项目根目录
- Submodule 模式下自动创建 `.harness/` 符号链接
- 补全 `.gitignore`
- 运行一次 `verify.sh` 验证环境

### 方式三：手动（最小化）

只需要 `.harness/` 目录和 `harness.yaml` 即可工作：

```bash
cp -r harness-core/.harness .harness
cp harness-core/harness.yaml harness.yaml
bash .harness/verify.sh
```

## 日常使用

```bash
# 运行全量验证（自动创建 .venv、安装工具链、执行所有检查）
bash .harness/verify.sh

# 带 Task ID（记录到遥测和进度文件）
bash .harness/verify.sh TASK-001

# 单独运行某个插件
bash .harness/plugins/python/run_linter.sh
bash .harness/plugins/python/run_typecheck.sh
bash .harness/plugins/python/run_tests.sh
python3 .harness/plugins/architecture/check_purity.py
```

## 配置

`harness.yaml` 是唯一的配置入口：

```yaml
version: 1.0
project_type: python

plugin_timeout: 300           # 每个插件的超时时间（秒）

paths:
  domain: src/domain          # 领域纯度扫描目标
  src: src                    # mypy + coverage 目标
  tests: tests                # 测试发现根目录

modules:
  linter:
    enabled: true
    plugin: ruff
  type_checker:
    enabled: true
    plugin: mypy
  tests:
    enabled: true
    coverage_threshold: 80    # 最低覆盖率
  domain_purity:
    enabled: true
```

## 五条架构法则

| 法则 | 名称 | 含义 |
|------|------|------|
| **Law 1** | 隔离 | `src/` 和 `.harness/` 严格分离 |
| **Law 2** | 零推断验证 | `verify.sh` 是唯一裁判，失败则自修（最多 5 次） |
| **Law 3** | 配置驱动 | `harness.yaml` 是唯一真相源，无魔法常量 |
| **Law 4** | 领域纯度 | `src/domain/` 只允许 stdlib + `src.domain.*` |
| **Law 5** | 可观测性 | 每次运行生成 `telemetry.json` + 追加历史 |

## 领域纯度扫描

`check_purity.py` 使用 AST 分析检测：

- **静态导入**：`import X` / `from X import Y`
- **动态导入**：`__import__()`、`exec()`、`eval()`、`compile()`
- **importlib 调用**：`importlib.import_module()`
- **越界相对导入**：`from .. import infrastructure`

## 质量门禁

| 门禁 | 工具 | 阈值 |
|------|------|------|
| Linting | ruff | 0 issues |
| Type Checking | mypy | 0 issues |
| Domain Purity | check_purity.py | 0 violations |
| Test Coverage | pytest-cov | >= harness.yaml 中配置的阈值 |
| All Tests | pytest | 100% pass |

## 给 AI Agent 的说明

`AGENTS.md` 是给 LLM Agent 阅读的**地图**（~70行），不是百科全书。它告诉 Agent "去哪里找"而非"所有细节"。

核心设计原则（来自 [OpenAI Codex 团队的实践](https://openai.com/zh-Hans-CN/index/harness-engineering/)和 [Anthropic 长运行 Agent 研究](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)）：

- **会话协议**：每个 Agent 会话有明确的 Startup Checklist（读进度、选任务、验证环境）和 Shutdown Checklist（验证、提交、写进度）
- **结构化特性列表**：`feature_list.json` 使用 JSON 格式的 pass/fail 状态跟踪，Agent 只能改 `passes` 字段，不能删除或修改描述
- **渐进式披露**：Agent 从一个小而稳定的切入点（AGENTS.md）开始，被引导去查看更深层的文档
- **执行计划**：`docs/exec-plans/active/` 和 `completed/` 分离活跃和已完成的计划
- **质量评分**：`docs/QUALITY_SCORE.md` 对每个领域打分，追踪差距

## License

MIT
