# Codex에 MCP Tool 등록하기

같은 `production-metrics` 서버를 Codex에 붙입니다. **server.py는 한 줄도 바꾸지 않습니다** —
이것이 MCP가 오픈 표준이라는 것의 실증입니다.

## 등록

```bash
# stdio 서버 등록. Codex는 실행 위치가 달라질 수 있으니 절대경로를 권장.
codex mcp add production-metrics -- python /absolute/path/to/harness-edu/tool/mcp-server/server.py
```

Windows 예:
```bash
codex mcp add production-metrics -- python C:\Work\harness-edu\tool\mcp-server\server.py
```

venv를 쓴다면 파이썬 대신 venv 파이썬 절대경로를 주세요:
```bash
codex mcp add production-metrics -- C:\Work\harness-edu\tool\mcp-server\.venv\Scripts\python.exe C:\Work\harness-edu\tool\mcp-server\server.py
```

## 관리 명령

```bash
codex mcp list                       # 등록된 MCP 서버 목록
codex mcp get production-metrics --json
codex mcp remove production-metrics
```

## 사용

Codex는 자동화에서 `codex exec`(비대화형)로 씁니다:

```bash
codex exec --sandbox read-only \
  "production-metrics MCP로 07-14 A·B·C 세 라인의 OEE를 구하고,
   가장 낮은 라인의 병목 축과 개선 포인트를 표로 정리해라"
```

- `--sandbox read-only`: 이 도구는 CSV를 읽기만 하므로 읽기 전용 샌드박스로 충분합니다.
  자동화의 가장 안전한 기본값입니다.
- 결과를 파일로 받으려면 `--output-last-message /tmp/oee.md`를 붙이세요.

## Claude Code 등록과의 차이

| | Claude Code | Codex |
|---|---|---|
| 등록 명령 | `claude mcp add ... -- python server.py` | `codex mcp add ... -- python server.py` |
| 파일 기반 공유 | `.mcp.json` (프로젝트 루트) | `~/.codex/config.toml`의 `[mcp_servers]` |
| 등록 범위 | `--scope project/user/local` | 사용자 전역(설정 파일) |

**요점**: 두 CLI는 각자 자기 도구 풀을 관리하므로 **양쪽에 각각 등록**해야 합니다. 하지만
등록 대상인 server.py는 완전히 동일합니다 — 도구의 원본은 하나입니다.

## 설정 파일로 등록 (재현성)

`codex mcp add`는 결국 `~/.codex/config.toml`에 아래 형태를 씁니다. 직접 편집해도 됩니다:

```toml
[mcp_servers.production-metrics]
command = "python"
args = ["C:\\Work\\harness-edu\\tool\\mcp-server\\server.py"]
```

이 블록을 팀 문서에 공유하면 누구나 같은 도구 환경을 재현할 수 있습니다.
