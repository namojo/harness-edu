# Codex 트랙 — 같은 실습, 다른 하네스

> `dashboard/` 실습(200대 설비 실시간 모니터링)을 **OpenAI Codex**로 수행하는 병행 트랙입니다.
> 목적은 도구 갈아타기가 아니라, **"방법론은 도구 중립이다"**를 몸으로 확인하고
> **"언제 멀티 에이전트가 정당화되는가"**라는 이 과정의 메타 질문에 데이터로 답하는 것입니다.

## 0. 왜 이 트랙인가

`dashboard/` 교안의 핵심 — 계약 확정 → 팬아웃 → 3점 교차 QA, 매핑 사전의 외부화 — 은 Claude Code 하네스에 종속된 것이 아닙니다. Codex에는 하네스 개념 대부분의 대응물이 존재합니다.

| harness (Claude Code) | Codex 대응물 | 비고 |
|---|---|---|
| `.claude/agents/{name}.md` | `.codex/agents/{name}.toml` | 커스텀 에이전트 정의 (모델·지침·스킬·샌드박스) |
| `.claude/skills/SKILL.md` | `.agents/skills/SKILL.md` | **동일 SKILL.md 포맷** — 거의 그대로 이식 |
| `CLAUDE.md` | `AGENTS.md` | 전역(~/.codex) → 프로젝트 → 하위 디렉토리 계층 병합 |
| 에이전트 팀 (P2P 자체 조율) | Subagents (허브-스포크 팬아웃) | 명시적 spawn, 부모가 결과 취합, 팀원 간 직접 통신 없음 |
| — | `codex mcp-server` + Agents SDK | 코드로 오케스트레이션 + 전 과정 트레이스 |

핵심 차이는 **팀 통신 모델**입니다. 하네스 팀은 팀원 간 SendMessage로 자체 조율(유연한 토론·상충 해소)하고, Codex는 부모가 서브에이전트를 명시적으로 생성·취합하는 허브-스포크(결정적·감사 가능)입니다. 트레이드오프이지 우열이 아닙니다 — 그걸 확인하는 게 이 트랙입니다.

## 1. 사전 준비

```bash
npm install -g @openai/codex   # 또는 brew install codex
codex login
git clone https://github.com/namojo/harness-edu.git
cd harness-edu/codex-track
```

이 디렉토리에는 실행 가능한 예시가 미리 들어 있습니다.

```
codex-track/
├── README.md                          ← 본 교안
├── AGENTS.md                          ← 프로젝트 불변 규칙 (Codex가 자동 로드)
├── .codex/agents/                     ← 커스텀 에이전트 정의 5종 (TOML)
│   ├── schema-architect.toml
│   ├── sim-api-builder.toml
│   ├── normalizer-eng.toml
│   ├── dashboard-builder.toml
│   └── qa-validator.toml
└── .agents/skills/
    └── vendor-payload-dict/SKILL.md   ← 크로스 플랫폼 스킬 (Claude Code에서도 동작)
```

> ⚠️ TOML 필드 구성은 Codex 버전에 따라 진화 중입니다. 실행 전 `codex --version`과 공식 문서(developers.openai.com/codex/subagents)로 필드명을 확인하세요.

## 2. 트랙 B — 단일 에이전트 원샷

가장 단순한 실행입니다. `dashboard/README.md`의 "실행 프롬프트" 4~5절을 그대로 사용합니다.

```bash
# dashboard 교안의 실행 프롬프트를 파일로 저장했다면:
codex exec "$(cat ../dashboard/README.md)" \
  --cd ./workspace-b -m gpt-5.3-codex
# 또는 대화형 TUI에서 프롬프트를 붙여넣기
```

**관찰 포인트**: 이 실습 규모(순수 HTML/JS, ~1,000줄)에서는 단일 에이전트도 완주할 가능성이 높습니다. 실제로 harness-edu의 완성 데모(namojo.github.io/dashboard-display)도 단일 에이전트 세션의 산출물입니다. 트랙 B의 존재 이유는 "멀티 에이전트가 항상 정답은 아니다"라는 기준선(baseline)을 세우는 것입니다.

## 3. 트랙 C — Codex 서브에이전트 팬아웃

`.codex/agents/`의 5개 에이전트 정의를 사용합니다. Codex는 **명시적으로 요청할 때만** 서브에이전트를 생성하므로, 대화형 세션에서 다음과 같이 지시합니다.

```
[1단계] schema-architect 에이전트를 생성해서 contracts/ 디렉토리에
SET v1 표준 스키마, SEMI E10 상태 매핑 사전, REST API 계약 문서를
작성하게 하고, 완료를 기다리세요.

[2단계] contracts/ 산출물을 확인한 뒤, 다음 3개 에이전트를 병렬로
생성하세요. 각자 contracts/의 계약만 참조해야 합니다.
- sim-api-builder → js/simulator.js, js/api.js
- normalizer-eng  → js/normalizer.js (.agents/skills/vendor-payload-dict 스킬 사용)
- dashboard-builder → index.html, css/, js/app.js, js/charts.js
셋 모두 완료되면 결과를 취합해 보고하세요.

[3단계] qa-validator 에이전트를 생성해서 3점 교차 비교
(원시값 = 정규화값 = 화면값)와 라인 필터·503 재시도 시나리오를
검증하게 하고, 발견된 결함을 해당 담당 에이전트에게 수정시키세요.
```

**관찰 포인트**:
- 게이트형 진행 — 부모(당신과 대화 중인 Codex)가 contracts/ 존재를 확인한 뒤에야 팬아웃합니다. 하네스의 schema-architect 선행 원칙이 오케스트레이션 지시문으로 표현된 것입니다.
- 서브에이전트끼리는 대화하지 않습니다. normalizer가 simulator의 페이로드 형식에 의문이 생기면? 계약 문서가 답해야 합니다. **계약의 완성도가 팬아웃의 성패를 좌우**한다는 사실이 하네스 트랙보다 더 선명하게 드러납니다.
- 서브에이전트 워크플로우는 동급 단일 실행보다 토큰을 더 소모합니다. 비용도 기록하세요.

## 4. 트랙 C+ (선택) — Agents SDK 오케스트레이션

더 큰 규모를 가정하면, Codex CLI를 MCP 서버(`codex mcp-server`)로 띄우고 OpenAI Agents SDK로 PM 에이전트가 핸드오프를 조율하는 구조로 확장할 수 있습니다. PM이 REQUIREMENTS를 만들고, 각 전문 에이전트의 산출물을 검증한 뒤 다음 단계로 넘기는 게이트형 핸드오프 — 그리고 전 과정이 트레이스로 기록되어 사후 감사가 가능합니다. 공식 가이드: `developers.openai.com/codex/guides/agents-sdk`

이 방식의 교육적 의미: **오케스트레이션이 프롬프트가 아닌 코드로 외부화**됩니다. 유연성은 줄지만 재현성과 감사 가능성은 최고 수준이 됩니다 — CI/CD에 넣을 수 있는 형태죠.

## 5. 3트랙 비교 실험 프로토콜

세 트랙 모두 동일한 검수 체크리스트(`dashboard/README.md` 5절)로 채점하고, 다음을 기록합니다.

| 측정 지표 | A. harness 팀 | B. Codex 단일 | C. Codex 서브에이전트 |
|---|---|---|---|
| 체크리스트 통과 (7항목 중) | | | |
| 1차 산출물의 결함 수 (QA 발견 기준) | | | |
| 재작업 라운드 수 | | | |
| 총 소요 시간 | | | |
| 토큰/비용 | | | |
| 계약 위반 사례 (스키마 불일치 등) | | | |

**예상되는 발견 (스포일러 아님 — 직접 확인하세요)**:
- B가 시간·비용 효율은 최고일 수 있으나, 자기 코드 QA의 확증 편향으로 결함 발견율이 낮을 수 있음
- C는 계약 문서가 부실하면 통합 단계에서 스키마 불일치가 터짐 — "계약이 병렬성을 만든다"의 실증
- A는 팀원 간 통신으로 상충을 스스로 해소하지만, 그 조율 과정 자체가 토큰을 소모

## 6. 교육 포인트

**① 방법론 > 도구.** 같은 SKILL.md가 양쪽에서 돌고, 에이전트 정의는 md ↔ toml 번역에 불과합니다. 여러분이 이 과정에서 쌓는 자산은 특정 CLI 사용법이 아니라 계약·역할·검증의 설계 능력입니다.

**② 통신 모델이 아키텍처를 결정합니다.** P2P 자체 조율(harness 팀)은 계약의 빈틈을 대화로 메우고, 허브-스포크(Codex)는 계약의 빈틈이 곧 결함이 됩니다. 후자가 더 엄격한 만큼, 계약 주도 개발의 훈련 효과는 오히려 Codex 트랙이 큽니다.

**③ 멀티 에이전트는 기본값이 아니라 선택입니다.** 트랙 B가 트랙 C를 이기는 규모가 분명히 존재합니다. "몇 명의 에이전트가 필요한가"를 묻기 전에 "혼자서 안 되는 이유가 무엇인가"를 먼저 물어야 합니다 — 이 실습의 비교표가 그 판단 근거를 제공합니다.

## 7. 심화 과제

1. **스킬 왕복 이식**: `.agents/skills/vendor-payload-dict`를 `.claude/skills/`로 복사해 하네스 트랙에서 사용하고, 수정 없이 동작하는지 확인해 보세요. 어떤 부분이 플랫폼 중립적이고 어떤 부분이 아닌지 기록하세요.
2. **계약 파괴 실험**: contracts/ 문서에서 단위 명세(초 vs ms) 한 줄을 일부러 삭제하고 트랙 C를 재실행해 보세요 — 어느 지점에서, 어떤 형태로 결함이 나타나는지 관찰하면 계약의 가치가 정량화됩니다.
3. **CI 배치화**: 트랙 B의 `codex exec`를 GitHub Actions에 넣어 "push 시 QA 에이전트 자동 실행" 파이프라인을 만들어 보세요.
