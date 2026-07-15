# 오픈소스 기반 Tool 만들기 — 나만의 MCP 서버로 에이전트 능력 확장하기

> 한빛정밀(가상) **품질관리팀**이, 매일 아침 라인별 OEE(설비종합효율)를 사람이 손으로
> 계산하던 일을 없애려 합니다. 방법은 프롬프트가 아니라 **도구(Tool)** 입니다.
> Python 40여 줄짜리 MCP 서버를 하나 만들어, Claude Code와 Codex가 **똑같이** 호출하는
> 사내 공용 계산기로 만들어 봅니다. 이 실습이 끝나면 "에이전트가 못 하는 일은
> 도구를 붙여 준다"라는 감각이 생깁니다.

이 과정의 다른 실습이 **Agent(누가)** 와 **Skill(무엇을·어떻게)** 을 다뤘다면,
여기서는 세 번째 축인 **Tool(무엇으로 실행하는가)** 을 만듭니다.

---

## 0. Agent · Skill · Tool — 세 축의 분업

| 축 | 무엇인가 | 형태 | 결정론? | 언제 쓰나 |
|---|---|---|---|---|
| **Agent** | 역할·경계 (누가) | 지시문(정의 파일) | — | 일을 나눠 맡길 때 |
| **Skill** | 지식·절차 (무엇을·어떻게) | 프롬프트에 주입되는 문서 | ✗ (모델이 해석) | 판단·문체·도메인 지식 |
| **Tool** | 실행 수단 (무엇으로) | **실제 코드/외부 시스템** | ✓ (항상 같은 값) | 계산·조회·외부 연동 |

핵심 구분: **Skill은 "설명서"고 Tool은 "계산기"** 입니다. Skill에 "OEE는 가동률×성능×품질"이라고
적어 두면 모델이 그 설명을 읽고 *직접 암산*합니다 — 숫자가 커지면 자주 틀립니다.
Tool은 그 계산을 **코드로 실행**하므로 몇 번을 돌려도 값이 같습니다.

> 판단 규칙 — **정의가 고정돼 있고 항상 같은 답이 나와야 하는 일**(계산·DB 조회·API 호출·
> 파일 파싱)은 Tool로. **맥락에 따라 달라지는 판단**(무엇이 중요한가·어떻게 쓸까)은 Skill로.

---

## 1. 왜 Tool인가 — LLM의 약점을 코드로 메운다

품질관리팀의 요청: "B라인 어제 OEE 알려줘."

**Tool 없이 (Skill 설명만 주고 모델이 암산):**
```
가동률 0.75쯤, 성능 0.94쯤... OEE 대략 70% 안팎으로 보입니다
```
그럴듯하지만 **검증 불가능**하고, 같은 질문에 매번 미묘하게 다른 값이 나옵니다.

**Tool 있이 (`compute_oee("B","2026-07-14")` 호출):**
```json
{ "availability": 0.75, "performance": 0.9444, "quality": 0.9853,
  "oee": 0.6979, "oee_pct": "69.8%", "bottleneck": "가동률" }
```
언제나 **69.8%**. 게다가 병목이 가동률(정지시간 120분)이라는 **진단**까지 코드가 계산합니다.

이것이 Tool의 존재 이유입니다 — LLM이 약한 일(정확한 산수, 외부 데이터 접근)을
**결정론적 코드**에 위임하고, LLM은 잘하는 일(해석·설명·다음 행동 제안)에 집중시킵니다.

---

## 2. MCP — "한 번 만들면 어디서나" 오픈 표준

우리가 만들 Tool은 **MCP(Model Context Protocol)** 서버입니다. MCP는 Anthropic이
공개한 **오픈 표준**이라, 이 서버 하나를 만들어 두면:

- **Claude Code**가 호출할 수 있고,
- **Codex**도 호출할 수 있고,
- 앞으로 나올 MCP 지원 클라이언트도 그대로 씁니다.

즉 "품질관리팀 OEE 계산기"를 클라이언트마다 다시 만들 필요가 없습니다. 이것이
사내 툴을 **자산**으로 만드는 방법입니다 — `xlsx/`의 표준용어집, `codex/`의 에이전트
정의와 같은 "프롬프트 밖으로 꺼내 파일로 굳힌다"의 도구 버전입니다.

```
tool/
├── README.md                  ← 본 교안
├── mcp-server/
│   ├── server.py              ← Tool 본체 (FastMCP, 약 40줄 + 주석)
│   ├── requirements.txt       ← mcp[cli]
│   └── data/production.csv    ← 샘플 생산 데이터 (라인 A·B·C)
├── register-claude-code.md    ← Claude Code에 등록하기
└── register-codex.md          ← Codex에 등록하기
```

---

## 3. 실습 A — Tool 만들고 실행하기

### 3.1 설치

```bash
git clone https://github.com/namojo/harness-edu.git
cd harness-edu/tool/mcp-server
python -m venv .venv && . .venv/Scripts/activate   # (mac/Linux: source .venv/bin/activate)
pip install -r requirements.txt
```

### 3.2 server.py 읽기 — Tool은 그냥 함수다

`server.py`의 핵심은 이게 전부입니다. **`@mcp.tool()` 데코레이터를 붙인 파이썬 함수가
곧 하나의 도구**가 됩니다.

```python
from mcp.server.fastmcp import FastMCP
mcp = FastMCP("production-metrics")        # 서버(=도구 묶음) 이름

@mcp.tool()
def compute_oee(line: str, date: str) -> dict:
    """지정한 라인·날짜의 OEE를 계산한다."""   # ← 이 docstring을 모델이 읽고 언제 쓸지 판단
    ...
    return { "oee_pct": "69.8%", ... }

if __name__ == "__main__":
    mcp.run()                              # stdio로 실행 — 에이전트가 이 프로세스와 통신
```

세 가지만 기억하면 됩니다:
1. **함수 시그니처**(`line: str, date: str`)가 곧 도구의 입력 스펙이 됩니다 — 타입 힌트 필수.
2. **docstring**이 도구 설명입니다. 모델은 이 문장을 읽고 *언제 이 도구를 부를지* 판단하므로,
   Skill의 description처럼 명확히 씁니다.
3. 반환값(dict)이 그대로 모델에게 전달됩니다.

이 서버에는 도구가 3개 있습니다: `list_records`(조회 가능 목록), `compute_oee`(OEE 계산),
`defect_ppm`(불량률 ppm).

### 3.3 서버가 살아 있는지 확인

MCP 서버는 보통 에이전트가 자동으로 띄우지만, 로직만 먼저 검증할 수 있습니다.

```bash
python -c "from server import compute_oee; print(compute_oee('B','2026-07-14'))"
# → {'availability': 0.75, ..., 'oee_pct': '69.8%', 'bottleneck': '가동률'}
```

같은 입력이면 언제나 같은 출력 — 이게 Skill(암산)과 결정적으로 다른 점입니다.

---

## 4. 실습 B — Claude Code에 붙이기

자세한 절차는 [`register-claude-code.md`](register-claude-code.md). 요약하면:

```bash
# tool/mcp-server 디렉토리에서
claude mcp add production-metrics -- python server.py
```

등록 후 Claude Code에서:
```
production-metrics 도구로 07-14 A·B·C 세 라인의 OEE를 구하고,
가장 낮은 라인의 병목이 무엇인지, 개선하려면 어디를 봐야 하는지 정리해줘.
```

**관찰 포인트**: 모델은 OEE를 스스로 계산하지 않습니다 — `compute_oee`를 세 번 호출해
정확한 값을 받아 온 뒤, 거기에 **해석**만 얹습니다. "정확한 산수는 도구, 해석은 모델"이라는
분업이 눈으로 보입니다.

---

## 5. 실습 C — Codex에도 붙이기 (같은 서버, 다른 클라이언트)

MCP가 오픈 표준이라는 게 여기서 증명됩니다. **코드를 한 줄도 바꾸지 않고** Codex에 등록합니다.
자세한 절차는 [`register-codex.md`](register-codex.md).

```bash
codex mcp add production-metrics -- python /절대경로/harness-edu/tool/mcp-server/server.py
codex mcp list          # 등록 확인
```

이제 `codex exec`에서 같은 도구를 씁니다:
```bash
codex exec --sandbox read-only \
  "production-metrics MCP로 07-14 B라인 OEE와 불량률(ppm)을 구하고 개선 우선순위를 제안해라"
```

**관찰 포인트**: `codex/` 실습에서 "같은 스킬을 Claude Code와 Codex 양쪽에 복사한다"라고
배웠던 것의 도구 버전입니다. 단, 스킬은 파일을 *복사*했지만 Tool은 **하나의 서버를 양쪽이
각자 등록**해 공유합니다 — 계산 로직의 원본이 한 곳뿐이라 유지보수가 더 쉽습니다.

---

## 6. 교육 포인트

**① Tool은 특별한 기술이 아니라 "함수에 데코레이터"다.** MCP의 진입장벽은 낮습니다.
평소 팀이 엑셀·파이썬으로 하던 계산을 `@mcp.tool()` 붙인 함수로 옮기면, 그 순간
모든 에이전트가 쓸 수 있는 사내 도구가 됩니다.

**② Skill과 Tool을 혼동하지 말 것.** "OEE 계산법"을 Skill 문서에 적으면 모델이 암산해
틀립니다. Tool로 만들면 코드가 계산해 항상 맞습니다. 반대로 "이 보고서를 어떤 톤으로 쓸까"는
Tool로 만들 수 없습니다 — 판단은 Skill, 실행은 Tool.

**③ 오픈 표준의 가치 = 한 번 만들어 여러 곳에서.** 같은 server.py를 Claude Code·Codex가
공유했습니다. 클라이언트가 늘어도 도구는 그대로입니다. 이것이 "사내 도구를 자산화한다"의 실체입니다.

**④ 좋은 Tool은 값만 주지 않고 진단을 준다.** `compute_oee`는 OEE 숫자만이 아니라
`bottleneck`(가장 낮은 축)까지 계산해 돌려줍니다. 도구가 한 걸음 더 계산해 주면,
모델은 그만큼 더 나은 해석을 얹을 수 있습니다.

---

## 7. 심화 과제

1. **도구 추가**: `weekly_trend(line)` 도구를 직접 작성해, 한 라인의 날짜별 OEE 추이와
   전일 대비 증감을 반환하게 하세요. `@mcp.tool()` 함수 하나를 더 붙이면 끝입니다.

2. **금융 도메인으로 확장**: 제조의 OEE 자리에 금융 지표를 넣어 보세요 — 예: 대출 포트폴리오
   CSV를 읽어 `compute_npl_ratio`(고정이하여신비율), `compute_bis`(자기자본비율)를 계산하는
   Tool. "정의가 고정된 규제 지표일수록 Tool이 정답"이라는 원리는 업종을 가리지 않습니다.

3. **실제 오픈소스 MCP 써 보기**: 세상에는 이미 공개된 MCP 서버가 많습니다. 예를 들어
   금융감독원 금융통계정보시스템(FISIS)을 MCP로 감싼 오픈소스 서버를 등록하면, 직접 만들지
   않고도 은행별 재무지표를 에이전트가 조회합니다. "만들기 전에, 이미 누가 만든 Tool이
   없는지 찾는다"도 중요한 엔지니어링 감각입니다.

4. **원격(HTTP) MCP**: 지금은 `python server.py`를 로컬에서 spawn하는 stdio 방식입니다.
   팀 전체가 공유하려면 서버를 HTTP로 띄우고 `claude mcp add --transport http ...`,
   `codex mcp add --url ...`로 등록합니다. 로컬 계산기가 **사내 API**로 승격되는 단계입니다.

5. **`codex-engineering/` 트랙과 연결**: 이 Tool을 `codex-engineering/`의 CI 파이프라인에
   넣어, 매일 아침 전 라인 OEE를 계산해 임계치 미달 라인을 자동 리포트하게 만들어 보세요.
   Tool(계산) + Agent(판단) + 스케줄(자동화)이 하나로 합쳐지는 지점입니다.
