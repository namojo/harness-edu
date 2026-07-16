
## Step 1 — 체크리스트 완료

스크립트 실행 전 [`SETUP_CHECKLIST_ko.md`](./setup/SETUP_CHECKLIST_ko.md)를 먼저 읽고 완료하세요.

주요 확인 사항:
- **Claude Pro/Max** 및 **Gemini Advanced** 구독 완료 (API Key가 아닌 구독 플랜)
- **GitHub 계정** 생성 및 `gh auth login` 준비
- 여유 디스크 공간 **5 GB 이상**, **관리자/sudo 권한** 보유 확인

---

## Step 2 — OS별 스크립트 실행

터미널을 관리자 / sudo 권한으로 열고 본인 OS에 맞는 스크립트를 실행하세요.

### macOS

```bash
bash setup-mac.sh
# 선택: WezTerm (GPU 가속 터미널) 함께 설치
bash setup-mac.sh --wezterm
# 선택: Docker Desktop 함께 설치
bash setup-mac.sh --docker
# 둘 다:
bash setup-mac.sh --wezterm --docker
```

### Linux (Ubuntu / Debian)

```bash
bash setup-linux.sh
# 선택: WezTerm 함께 설치
bash setup-linux.sh --wezterm
# 선택: Docker 함께 설치
bash setup-linux.sh --docker
# 둘 다:
bash setup-linux.sh --wezterm --docker
```

### Windows

**PowerShell을 관리자 권한으로 실행**한 뒤 아래 명령어를 입력하세요:

```powershell
# 기본 실행 (Execution Policy은 스크립트가 자동으로 설정합니다)
.\setup-windows.ps1

# 옵션:
.\setup-windows.ps1 -WSL2             # WSL2 함께 설치 (재시작 필요)
.\setup-windows.ps1 -WezTerm          # WezTerm 함께 설치
.\setup-windows.ps1 -Docker            # Docker Desktop 함께 설치
.\setup-windows.ps1 -Force             # 이미 설치된 도구도 모두 재설치
.\setup-windows.ps1 -WSL2 -WezTerm -Docker  # 선택 옵션 전부 설치
```

> **실행 후**: 터미널을 닫고 다시 열어 PATH 변경 사항을 반영하세요.

---

## Step 3 — 설치 확인

```bash
bun setup-common.ts
```

설치된 도구의 검증 표를 출력합니다. **모든 항목이 ✅로 표시되면 준비 완료입니다.**

---

## 설치 도구 목록

| 도구 | 용도 | macOS | Linux | Windows |
|------|------|-------|-------|---------|
| **bun** | 런타임 & 패키지 매니저 | `bun.sh/install` | `bun.sh/install` | `bun.sh/install.ps1` |
| **git** | 버전 관리 | `brew install git` | `apt install git` | `winget Git.Git` |
| **gh** | GitHub CLI | `brew install gh` | apt (공식 저장소) | `winget GitHub.cli` |
| **python3** | Python 런타임 | `brew install python3` | `apt install python3` | `winget Python.Python.3.13` |
| **uv** | Python 패키지 매니저 | `brew install uv` | `astral.sh/uv/install.sh` | `winget astral-sh.uv` |
| **claude** | Claude Code CLI | `bun install -g @anthropic-ai/claude-code` | `bun install -g @anthropic-ai/claude-code` | `bun install -g @anthropic-ai/claude-code` |
| **agy** | Antigravity CLI | `antigravity.google/cli/install.sh` | `antigravity.google/cli/install.sh` | `antigravity.google/cli/install.ps1` |
| **Google Chrome** | 브라우저 | `brew install --cask google-chrome` | `.deb` 직접 다운로드 | `winget Google.Chrome` |
| **Claude Desktop** | Claude 데스크탑 앱 | `brew install --cask claude` | ⚠️ 수동 설치 | `winget Anthropic.Claude` |
| **Antigravity Desktop** | Antigravity 데스크탑 앱 | ⚠️ 수동 설치 | ⚠️ 수동 설치 | ⚠️ 수동 설치 |
| **Mark** | Markdown 뷰어 | ⚠️ 수동 설치 | ⚠️ 수동 설치 | ⚠️ 수동 설치 |
| **PowerShell 7+** | 셸 | — | — | `winget Microsoft.PowerShell` |
| **Windows Terminal** | 터미널 | — | — | `winget Microsoft.WindowsTerminal` |
| **unzip** | 압축 해제 | — (기본 내장) | `apt install unzip` | — (기본 내장) |
| **curl** | HTTP 클라이언트 | — (기본 내장) | `apt install curl` | — (기본 내장) |

> ⚠️ 항목은 직접 다운로드 및 수동 설치가 필요합니다.

### 선택 도구 (`--wezterm`, `--docker`)

| 도구 | macOS | Linux | Windows |
|------|-------|-------|---------|
| **WezTerm** (`--wezterm`) | `brew install --cask wezterm` | apt (fury.io 저장소) | `winget wez.wezterm` |
| **Docker** (`--docker`) | `brew install --cask docker` | `get.docker.com` 스크립트 | `winget Docker.DockerDesktop` |
| **WSL2** (`-WSL2`, Windows 전용) | — | — | `wsl --install` |

---

## 터미널 앱 추천 (Windows)

| 앱 | 설명 | 설치 |
|----|------|------|
| **Windows Terminal** ⭐ | Microsoft 공식, 탭·WSL 통합 — 기본 권장 | `winget install Microsoft.WindowsTerminal` |
| **WezTerm** | GPU 가속·멀티플렉서 내장·크로스플랫폼 — 파워유저 추천 | `winget install wez.wezterm` |

WezTerm 자동 설치: `.\setup-windows.ps1 -WezTerm`

---

## 문제 해결

**설치 후 `bun: command not found`**
터미널을 재시작하세요. Windows에서는 bun이 User 환경변수에 자동으로 등록됩니다. macOS/Linux:
```bash
export PATH="$HOME/.bun/bin:$PATH"
```

**`bun install -g` 후 `claude: command not found`**
스크립트가 bun 실패 시 npm fallback으로 자동 재시도합니다. 여전히 문제가 있다면 `bun pm ls -g`로 경로를 확인한 뒤 PATH에 추가하세요.

**설치 후 `agy: command not found`**
Antigravity CLI 설치 스크립트는 바이너리를 `~/.local/bin` 또는 `/usr/local/bin`에 저장합니다. `source ~/.bashrc`를 실행하거나 터미널을 재시작하세요.

**Windows: `스크립트 실행이 비활성화되어 있습니다`**
스크립트가 자동으로 `RemoteSigned`로 설정합니다. 수동으로 변경하려면:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Windows: 관리자 권한 없이 실행한 경우**
스크립트가 경고를 표시하지만 계속 진행됩니다. winget 등 일부 설치에서 오류가 발생할 수 있으므로 권장: PowerShell을 관리자 권한으로 재실행하세요.

**설치 로그 확인**
Windows 스크립트 실행 로그는 `%USERPROFILE%\workshop-setup-logs\`에 자동 저장됩니다.

---

> `bun setup-common.ts`를 실행해서 모든 항목이 ✅로 표시되면 워크숍 준비 완료입니다.

---

0. Claude Code 설치 (수동)
```
irm https://claude.ai/install.ps1 | iex
```

2. 경로 추가 (옵션) — claude 경로 설정이 안된 경우에 만
```
$claudePath = "$env:USERPROFILE\.local\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$claudePath*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$claudePath", "User")
}
```

2. Harness 설치
https://github.com/revfactory/harness

```
/plugin marketplace add revfactory/harness
/plugin install harness@harness-marketplace
```

3. Anthropic Skill 설치
https://github.com/anthropics/skills

```
/plugin marketplace add anthropics/skills
/plugin install document-skills@anthropic-agent-skills
```

---

# 학습 지도 (커리큘럼)

하네스로 일하는 법을 **입문 → 실무 → 확장** 순으로 익힙니다. 각 폴더의 README가 독립된 실습입니다.

> 🧭 **혼자 순서대로 따라 하려면 → [`자가학습_가이드.md`](자가학습_가이드.md)** 를 먼저 여세요.
> 무엇을 어떤 순서로, 무엇을 관찰하며, 어디까지 됐으면 다음으로 넘어갈지를 안내합니다.
> 응용 과제는 [`실습.txt`](실습.txt)에 있습니다.

## 1. 입문 — 하네스가 무엇을 바꾸는가

| 폴더 | 무엇을 배우나 | 도구 |
|---|---|---|
| [`xlsx/`](xlsx/) | 표준용어집을 자산화해 반복 데이터 작업을 재현 | Claude Code |
| [`codex/`](codex/) | 단일 → 멀티 → 하네스형 3단계 (코딩 몰라도 OK) | Codex |
| [`harness/`](harness/) | 단일 프롬프트 vs 전문가 에이전트 팀 A/B 비교 | Claude Code + `/harness` |

## 2. 실무 — 매일 돌리는 하네스 엔지니어링 · 🆕

| 폴더 | 무엇을 배우나 | 대상 |
|---|---|---|
| [`codex-engineering/`](codex-engineering/) | Codex 실무 하네스: 샌드박스·승인정책·CI·출력 계약 | 2트랙 |
| ├ [트랙 A · 엔지니어링](codex-engineering/track-a-engineering/) | `codex exec` 패치·`codex review`·CI 게이트 | 개발·데이터 담당 |
| └ [트랙 B · 업무 자동화](codex-engineering/track-b-ops/) | `--search`·`--output-schema`·정례 자동화 | 코드 안 짜는 실무자 |

## 3. 확장 — 에이전트에 없는 능력을 붙이기 · 🆕

| 폴더 | 무엇을 배우나 | 도구 |
|---|---|---|
| [`tool/`](tool/) | 오픈소스 MCP 서버(Python)로 나만의 Tool 만들기 | Claude Code + Codex 공용 |

**세 축 정리** — 하네스는 결국 세 가지의 조합입니다:
- **Agent** (누가) — 역할·경계. `harness/`, `codex/`에서.
- **Skill** (무엇을·어떻게) — 지식·절차. 각 폴더의 `.claude/skills`, `.agents/skills`에서.
- **Tool** (무엇으로 실행) — 결정론적 코드·외부 연동. `tool/`에서. 🆕

입문에서 Agent·Skill을, 실무에서 그것들을 안전하게 반복시키는 엔지니어링을, 확장에서
세 번째 축인 Tool을 직접 만들어 봅니다.
