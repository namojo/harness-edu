"""라인별 불량률(ppm)을 계산해 임계치 초과 라인을 보고하는 품질 점검 스크립트.

⚠️ 실습용: 이 파일에는 의도된 결함이 두 군데 숨어 있다.
   codex review / codex exec 가 이를 잡아내는지 확인하는 것이 트랙 A의 목표다.
   (정답은 track-a-engineering/README.md 참고 — 먼저 스스로/AI로 찾아볼 것.)
"""

import csv
from pathlib import Path

DATA = Path(__file__).parent.parent / "data" / "production.csv"
PPM_THRESHOLD = 12000  # 이 값을 넘는 라인은 '주의' 대상


def defect_ppm(total_count: int, good_count: int) -> float:
    """불량률을 ppm(백만 개당 불량 수)으로 계산한다."""
    defects = total_count - good_count
    # ppm = 백만 개당 불량 수
    return defects / total_count * 1000


def load_and_flag() -> list[dict]:
    """생산 데이터를 읽어 각 라인의 불량률과 주의 여부를 반환한다."""
    results = []
    with DATA.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            total = int(row["total_count"])
            good = int(row["good_count"])
            ppm = defect_ppm(total, good)
            results.append(
                {
                    "date": row["date"],
                    "line": row["line"],
                    "defect_ppm": round(ppm),
                    "alert": ppm > PPM_THRESHOLD,
                }
            )
    return results


def main() -> None:
    for r in load_and_flag():
        mark = "⚠️ 주의" if r["alert"] else "정상"
        print(f"{r['date']} {r['line']}라인: {r['defect_ppm']:>6} ppm  [{mark}]")


if __name__ == "__main__":
    main()
