---
name: vendor-payload-dict
description: 디스플레이 FAB 설비의 벤더별 이기종 텔레메트리 페이로드(Canon SECS 숫자코드, Nikon·TEL snake_case·ms단위, 국산 한글 키, 레거시 CSV 문자열)를 SET v1 표준 스키마로 정규화하는 매핑 사전. 설비 페이로드의 필드 해석, 단위 변환, 상태코드 매핑, 어댑터 구현·수정이 필요한 모든 작업에서 반드시 이 스킬을 사용할 것. 신규 벤더 온보딩 시 이 사전에 행을 추가한다.
---

# 벤더 페이로드 매핑 사전 (→ SET v1)

이 사전이 유일한 진실 공급원이다. 매핑을 코드에 하드코딩하지 말고 이 사전을 따르라.
사전에 없는 필드·상태값을 만나면 임의 해석하지 말고 `[미확인]`으로 격리 보고하라 —
잘못 해석된 설비 상태는 잘못된 공정 판단으로 이어진다.

## 상태 매핑 (→ SEMI E10)

| SET v1 state | Canon (숫자) | Nikon·TEL (E10 명칭) | 국산 (한글) | 레거시 (1글자) |
|---|---|---|---|---|
| RUN   | 1 | PRODUCTIVE      | 가동     | R |
| IDLE  | 2 | STANDBY         | 대기     | I |
| SETUP | 3 | ENGINEERING     | 셋업     | S |
| PM    | 4 | SCHEDULED_DT    | 예방정비 | P |
| DOWN  | 5 | UNSCHEDULED_DT  | 비가동   | D |

## 필드 매핑

| SET v1 필드 | Canon 계열 | Nikon·TEL 계열 | 국산 계열 | 레거시 CSV(인덱스) |
|---|---|---|---|---|
| id        | EqpID      | machine_no      | 설비ID     | [0] |
| model     | MDLN       | model_name      | 기종       | [1] |
| state     | OpState    | run_mode        | 상태       | [2] |
| produced  | GlassCnt   | count_out       | 생산수량   | [3] |
| target    | TgtCnt     | plan_count      | 목표수량   | [4] |
| uph       | PPH        | throughput_pph  | 시간당생산 | [5] |
| yieldPct  | Yld        | yield_pct       | 수율       | [6] |
| tactSec   | TactTime   | cycle_time_ms   | 택트       | [7] |
| tempC     | ChmbrTemp  | stage_temp_c    | 온도       | [8] |
| alarms    | AlarmSet   | alarm_str       | 알람       | [9] |
| updatedAt | TimeStamp  | ts_epoch        | 기준시각   | ts |

## 단위 변환 규칙 (어댑터의 책임)

- **Nikon·TEL `cycle_time_ms`**: ms → 초. `tactSec = cycle_time_ms / 1000` (83000 → 83).
- **Canon `Yld`**: 0~1 비율 → %. `yieldPct = Yld * 100` (0.9782 → 97.82).
- **Nikon·TEL `ts_epoch`**: epoch 초 → epoch ms. `updatedAt = ts_epoch * 1000`.
- **국산 `기준시각`**: ISO 8601 문자열 → epoch ms. `Date.parse()`.
- 나머지 필드는 단위 변환 없이 매핑만 한다.

## 알람 구조 변환

- Canon `AlarmSet`: `[{ALID, ALTX}]` → `[{code: ALID, text: ALTX}]`
- Nikon·TEL `alarm_str`: `"E-101:내용;E-204:내용"` → 세미콜론 분리 후 첫 콜론에서
  code/text 분할. 빈 문자열이면 빈 배열.
- 국산 `알람`: `[{코드, 내용}]` → `[{code, text}]`
- 레거시 `[9]`: `"AL-101|AL-204"` → 파이프 분리, text는 `"(레거시 코드)"` 고정.

## 신규 벤더 온보딩 절차

1. 원시 페이로드 샘플 3건 이상을 확보해 필드 목록을 만든다.
2. 이 문서의 상태·필드·단위·알람 표에 열(또는 행)을 추가한다.
3. 어댑터를 사전 기준으로 구현하고, 3점 교차 비교(원시=정규화=화면)로 검증한다.
4. 매핑 불가 필드는 unknownFields로 보고하고 사람의 판정을 받는다.
