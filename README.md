Claude 설치


1. Git & Python 설치
https://git-scm.com/install/windows
https://www.python.org/downloads/

3. Claude 설치
```
irm https://claude.ai/install.ps1 | iex
```

3. 설치 확인 — 결과가 True 면 정상
```
Test-Path "$env:USERPROFILE\.local\bin\claude.exe"
```

4. 경로 추가 (필수) — 아래 네 줄을 그대로 붙여넣고 Enter
```
$claudePath = "$env:USERPROFILE\.local\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$claudePath*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$claudePath", "User")
}
```

5. Harness 설치
https://github.com/revfactory/harness

```
/plugin marketplace add revfactory/harness
/plugin install harness@harness-marketplace
```

6. Anthropic Skill 설치
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
