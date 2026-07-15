"""quality_check 테스트.

⚠️ 실습용: 이 테스트는 '초록불'이 나지만 결함을 잡지 못한다.
   구조(키·개수·상대 크기)만 검사하고 절대값·경계값은 검사하지 않기 때문이다.
   "테스트 통과 ≠ 정확"을 보여 주는 장치다 — 그래서 리뷰가 따로 필요하다.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from quality_check import defect_ppm, load_and_flag  # noqa: E402


def test_load_returns_all_lines():
    results = load_and_flag()
    assert len(results) == 3
    for r in results:
        assert {"date", "line", "defect_ppm", "alert"} <= r.keys()


def test_a_line_is_best():
    # 상대 비교만 한다 — 단위가 틀려도(×1000이든 ×1_000_000이든) 순위는 같으므로 통과한다.
    by_line = {r["line"]: r["defect_ppm"] for r in load_and_flag()}
    assert by_line["A"] < by_line["B"]
    assert by_line["A"] < by_line["C"]


def test_defect_ppm_is_positive():
    assert defect_ppm(1000, 990) > 0
    # 참고: 여기서 절대값(정상이라면 10000 ppm)을 단언하지 않는다.
    #       0으로 나누는 경계(total_count == 0)도 검사하지 않는다.
