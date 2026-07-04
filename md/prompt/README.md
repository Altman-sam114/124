# Prompt 工作流说明

本文记录阶段 prompt 的协作规则。具体业务阶段仍放在对应 `md/prompt/...` 子目录，本文件只写通用约束。

## 1. 角色召唤

- 用户消息以 `agenta`、`a:` 或 `A:` 开头，表示召唤 Agent A。
- 用户消息以 `agentb`、`b:` 或 `B:` 开头，表示召唤 Agent B。
- 用户消息以 `agentc`、`c:` 或 `C:` 开头，表示召唤 Agent C。
- 没有这些前缀时，按普通 Codex 任务处理；若任务需要 A/B/C 分工，先说明本轮按普通任务执行或请用户指定角色。

身份标识：

- Agent A 最终回复第一行必须写：`我是 Agent A。`
- Agent B 最终回复第一行必须写：`我是 Agent B。`
- Agent C 最终回复第一行必须写：`我是 Agent C。`

## 2. Agent A 提示词要求

Agent A 写给 Agent B 的阶段提示词必须包含：

- 本轮目标与非目标。
- 必读文档、相关源码和当前架构依据。
- 明确要求基于最新 `origin/main`，在 `main` 上实现、提交和推送。
- 本机只运行 `md/test/test.md` 允许的轻量检查。
- 完成后 `git push origin main` 触发 GitHub Actions。
- 云端 workflow 需要生成未加密 CI 结果包。
- Agent C 需要下载并核对 `ci-artifact-manifest.json`、`junit.xml` 或等价摘要、主日志、failure summary、run id、run attempt 和 commit SHA。
- CI 失败时，不默认回滚；Agent B 在 `main` 上追加修复 commit 后重新 push。
- 不引入 `smalldata_test`、`develop`、`codeb/...`、候选分支或 PR 合并流，除非人工另行明确要求。

## 3. Agent B 实现要求

Agent B 默认流程：

```sh
git fetch origin
git switch main
git pull --ff-only origin main
git status --short
```

然后按 Agent A 提示词实现，运行轻量检查，提交并推送：

```sh
git add 相关文件
git commit -m "vX.Y: 简要说明本轮做了什么"
git push origin main
```

推送前必须确认：

- 当前分支是 `main`。
- 远端目标是 `origin/main`。
- 提交范围只包含本轮相关文件和用户已要求上传的项目改动。
- `.worktrees/`、DerivedData、build 产物、secret、证书和密码文件没有进入提交。

## 4. Agent C 验收要求

Agent C 默认流程：

```sh
gh auth login
mkdir -p /private/tmp/wwiihexv0-c-review-<run_id>
gh run download <run_id> --dir /private/tmp/wwiihexv0-c-review-<run_id>
```

Agent C 必须核对：

- `origin/main` 最新 commit SHA。
- GitHub Actions run id 和 run attempt。
- artifact 名称与 manifest 内容。
- manifest 中 `branch=main`、`commitSha`、`runId`、`runAttempt` 是否匹配。
- `ci-failure-summary.md`、`junit.xml`、`xcodebuild.log` 和可用的 `.xcresult`。

未完成下载或核对时，不能声称云端验收通过。
