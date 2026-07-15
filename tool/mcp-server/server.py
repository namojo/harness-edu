"""생산지표 MCP 서버 — 오픈소스 기반 Tool 만들기 실습

이 파일 하나가 곧 '오픈소스 Tool'이다. Model Context Protocol(MCP)은
Anthropic이 공개한 오픈 표준이며, 여기서 정의한 tool은 Claude Code·Codex 등
MCP를 지원하는 어떤 에이전트든 그대로 호출할 수 있다.

핵심 교육 포인트:
  LLM은 480/(480-47) 같은 계산을 '눈대중'으로 하면 자주 틀린다.
  OEE(설비종합효율)처럼 정의가 고정된 값은 '코드로 실행'해야 항상 같은 답이 나온다.
  Skill이 '지식·절차'라면, Tool은 '결정론적 실행'이다.
"""

import csv
from pathlib import Path

from mcp.server.fastmcp import FastMCP

# 서버 이름 — 에이전트가 도구 목록에서 이 이름으로 인식한다.
mcp = FastMCP("production-metrics")

DATA = Path(__file__).parent / "data" / "production.csv"


def _load_rows() -> list[dict]:
    """번들된 생산 데이터를 읽어 숫자 필드를 형변환한다."""
    with DATA.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        for k in ("planned_minutes", "downtime_minutes", "total_count", "good_count"):
            r[k] = int(r[k])
        r["ideal_cycle_time_sec"] = float(r["ideal_cycle_time_sec"])
    return rows


def _find(line: str, date: str) -> dict | None:
    for r in _load_rows():
        if r["line"].upper() == line.upper() and r["date"] == date:
            return r
    return None


@mcp.tool()
def list_records() -> list[dict]:
    """조회 가능한 (날짜, 라인) 목록을 반환한다. 어떤 데이터가 있는지 먼저 확인할 때 쓴다."""
    return [{"date": r["date"], "line": r["line"]} for r in _load_rows()]


@mcp.tool()
def compute_oee(line: str, date: str) -> dict:
    """지정한 라인·날짜의 OEE(설비종합효율)를 계산한다.

    OEE = 가동률(Availability) × 성능(Performance) × 품질(Quality)
      - 가동률 = (계획시간 - 정지시간) / 계획시간
      - 성능   = (이상 사이클타임 × 총생산량) / 실가동시간
      - 품질   = 양품수 / 총생산량

    Args:
        line: 라인 코드 (예: "A", "B", "C")
        date: 날짜 (YYYY-MM-DD)
    """
    r = _find(line, date)
    if r is None:
        return {"error": f"{date} {line}라인 데이터를 찾을 수 없습니다. list_records로 확인하세요."}

    run_time_min = r["planned_minutes"] - r["downtime_minutes"]
    availability = run_time_min / r["planned_minutes"]
    performance = (r["ideal_cycle_time_sec"] * r["total_count"]) / (run_time_min * 60)
    quality = r["good_count"] / r["total_count"]
    oee = availability * performance * quality

    return {
        "date": r["date"],
        "line": r["line"],
        "availability": round(availability, 4),
        "performance": round(performance, 4),
        "quality": round(quality, 4),
        "oee": round(oee, 4),
        "oee_pct": f"{oee * 100:.1f}%",
        # 병목 진단: 세 지표 중 가장 낮은 축이 개선 우선순위다.
        "bottleneck": min(
            [("가동률", availability), ("성능", performance), ("품질", quality)],
            key=lambda x: x[1],
        )[0],
    }


@mcp.tool()
def defect_ppm(line: str, date: str) -> dict:
    """지정한 라인·날짜의 불량률을 ppm(백만 개당 불량 수)으로 계산한다."""
    r = _find(line, date)
    if r is None:
        return {"error": f"{date} {line}라인 데이터를 찾을 수 없습니다."}

    defects = r["total_count"] - r["good_count"]
    ppm = defects / r["total_count"] * 1_000_000
    return {
        "date": r["date"],
        "line": r["line"],
        "total_count": r["total_count"],
        "defects": defects,
        "defect_ppm": round(ppm),
    }


if __name__ == "__main__":
    # stdio 트랜스포트로 실행 — 에이전트(클라이언트)가 이 프로세스를 spawn 해서 통신한다.
    mcp.run()
