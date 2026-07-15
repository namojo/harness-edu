# 트랙 A — 엔지니어링: Codex로 코드 유지보수·리뷰·CI 게이트

> 제조 현장의 **품질 점검 스크립트**(`src/quality_check.py`)를 소재로, Codex를
> 실무 개발 흐름에 넣는 법을 배웁니다: 비대화형 패치(`codex exec`) → 교차 리뷰
> (`codex review`) → CI 자동 게이트. 이 스크립트에는 **의도된 결함 2개**가 숨어
> 있습니다. 초록불(테스트 통과) 뒤에 숨은 버그를 Codex가 잡아내는지 실험합니다.

## 0. 예제 구성

```
track-a-engineering/
├── src/quality_check.py      ← 라인별 불량률(ppm) 점검 — 결함 2개 내장
├── tests/test_quality_check.py ← 통과하지만 결함을 못 잡는 테스트 (일부러)
├── data/production.csv        ← 라인 A·B·C 생산 데이터
└── .github/workflows/codex-review.yml  ← PR마다 자동 리뷰하는 CI
```

먼저 현재 상태를 직접 확인하세요:

```bash
cd codex-engineering/track-a-engineering
pip install pytest
python -m pytest tests/ -q          # → 3 passed  (초록불!)
python src/quality_check.py         # → 전 라인 '정상'으로 표시됨
```

테스트도 통과하고 출력도 멀쩡해 보입니다. **하지만 세 라인 모두 실제 불량률은
ppm 기준 위험 수준**입니다(C라인 16,393 ppm). 여기서 트랙 A가 시작됩니다.

---

## 1. `codex exec` 읽기 전용 진단 — 권한 없이 문제만 찾기

가장 먼저, **아무 권한도 주지 않고** 무엇이 문제인지만 물어봅니다. 읽기 전용이라
안전하고, git 상태(커밋 여부)와 무관하게 파일을 그대로 읽습니다.

```bash
codex exec --sandbox read-only \
  --output-last-message /tmp/diag.md \
  "src/quality_check.py 를 검토해라. 테스트는 통과하지만 불량률(ppm) 계산과
   경계 처리에 결함이 있는지, 있다면 무엇인지 근거와 함께 진단해라. 수정은 하지 마라."
```

`--sandbox read-only`이므로 Codex는 파일을 못 고칩니다 — 진단만 받습니다. (자주 쓴다면
`.codex/config.example.toml`을 `~/.codex/config.toml`에 반영하고 `-p review`로 대체 가능.)

**관찰 포인트**: 테스트가 통과했는데도(§0에서 3 passed 확인) 진단이 결함을 지적한다면,
"테스트 통과 ≠ 정확"이 증명된 것입니다. 이것이 검증을 테스트와 **별도로** 두는 이유입니다.

---

## 2. `codex exec` 쓰기 권한 패치 — 진단이 타당하면 그때 권한을

진단이 맞다고 판단되면 그때 쓰기 권한을 줍니다.

```bash
codex exec --sandbox workspace-write \
  --output-last-message /tmp/patch.md \
  "src/quality_check.py 의 불량률 계산 단위 오류(ppm은 ×1_000_000)와 0 나눗셈 경계를
   수정하고, tests/ 에 절대값·경계값 테스트를 추가해 실제로 결함을 잡도록 강화한 뒤
   pytest 로 통과를 확인해라. 변경 요약을 남겨라."
```

`workspace-write`는 작업 루트 안에서만 씁니다. 비대화형이라 사람에게 묻지 않으므로,
끝난 뒤 diff를 사람이 검토하는 흐름을 유지하세요.

---

## 3. `codex review` — 내 수정본을 분리된 눈으로 교차 검증

패치를 하고 나면 이제 **커밋 안 된 변경(=방금 만든 수정)** 이 생깁니다. `codex review`는
바로 이 diff를 정형화된 포맷으로 리뷰합니다 — 구현자가 아닌 **분리된 눈**입니다.

```bash
codex review --uncommitted | tee review.md      # 방금 만든 수정분을 리뷰
# 브랜치로 작업했다면:  codex review --base main --title "품질 스크립트 점검"
```

`codex exec`와 달리 리뷰 포맷이 정형화돼 있어 발견 항목이 일관된 형태로 나옵니다. 결과는
stdout으로 흐르니 `tee`로 저장하세요.

> 참고: `codex review`는 **변경분(diff)** 을 리뷰하는 명령입니다. 갓 클론해 변경이 없는
> 상태에서는 리뷰할 대상이 없으므로, 원본 파일의 결함 진단은 §1의 읽기 전용 `codex exec`로,
> 리뷰는 수정을 만든 뒤(§2 이후) 하는 것이 자연스러운 순서입니다.

---

## 4. 정답 — 숨어 있던 결함 2개

스스로/Codex로 찾아본 뒤 펼쳐 보세요.

<details>
<summary>결함 공개</summary>

1. **단위 오류** (`defect_ppm`): `defects / total_count * 1000` — ppm은 백만 개당 수이므로
   `* 1_000_000`이어야 합니다. `* 1000`은 ‰(퍼밀) 수준이라, 실제 9,950~16,393 ppm인
   불량률이 10~16으로 표시됩니다. 그 결과 `PPM_THRESHOLD = 12000` 경보가 **영원히
   울리지 않습니다.** 위험한 라인이 "정상"으로 통과하는, 조용하지만 치명적인 버그입니다.

2. **0 나눗셈 경계**: `total_count == 0`(생산 없는 날/빈 행)이면 `defects / total_count`가
   `ZeroDivisionError`로 죽습니다. 가드가 없습니다.

**왜 테스트가 못 잡았나**: 테스트는 (a) 키·개수 등 구조, (b) 라인 간 상대 크기만 검사합니다.
단위가 틀려도 순위는 같고, 빈 행 케이스는 아예 없습니다. **초록불은 "검사한 것이 맞다"는
뜻이지 "코드가 맞다"는 뜻이 아닙니다.**

</details>

---

## 5. CI 게이트 — 리뷰를 잊지 않도록 자동화

`.github/workflows/codex-review.yml`은 PR이 열릴 때마다 ① 테스트를 돌리고 ②
`codex review`로 자동 리뷰해 결과를 아티팩트로 남깁니다. 사람이 리뷰를 깜빡해도
파이프라인이 **검증자 분리 원칙을 강제**합니다.

실사용 준비:
- 저장소 **Settings → Secrets and variables → Actions**에 `OPENAI_API_KEY` 등록
- 조직 정책상 CI에서 외부 모델 호출이 가능한지 먼저 확인

---

## 6. 교육 포인트

**① 초록불을 믿지 마라.** 통과하는 테스트는 "검사 대상만" 보증합니다. 단위·경계·누락은
테스트가 없으면 통과가 곧 위험 신호입니다. 그래서 리뷰가 테스트와 별개로 필요합니다.

**② 권한은 단계적으로 준다.** 먼저 `read-only`로 진단만 받고(§1), 진단이 타당할 때만
`workspace-write`로 패치(§2). "일단 고쳐 봐"보다 안전하고, 사람이 개입할 지점이 생깁니다.

**③ 구현자 ≠ 승인자.** `implementer.toml`은 자기 결과를 최종 승인하지 않고, `reviewer.toml`/
`codex review`가 교차 검증합니다. `harness/`의 compliance-reviewer 분리와 같은 원리입니다.

**④ 두 번째 의견으로서의 Codex.** Claude Code로 짠 코드를 Codex에게 리뷰시키면, 같은 모델의
자기 확증을 피한 독립 시각을 얻습니다 — 반대도 마찬가지입니다.

## 7. 심화 과제

1. **회귀 방지**: 패치 후 추가된 테스트가 원래 버그(×1000, 0 나눗셈)를 정말 잡는지,
   버그를 일부러 되돌려 확인하세요(빨간불이 떠야 정상).
2. **stdin 리뷰**: `git diff main..HEAD | codex exec --sandbox read-only -o /tmp/r.md "이 diff를
   위험·개선·테스트가능성 순으로 리뷰해라"` 로 대용량 diff를 넘겨 보세요.
3. **Tool 연결**: `tool/`의 `production-metrics` MCP를 이 스크립트 대신 써서, 계산을 Tool에
   위임하고 스크립트는 임계치 판정·리포트만 하게 리팩터하세요. "계산은 Tool, 판정은 코드"의
   경계가 잡힙니다.
