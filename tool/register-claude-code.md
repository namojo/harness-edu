# Claude Code에 MCP Tool 등록하기

`production-metrics` 서버를 Claude Code에 붙이는 세 가지 방법입니다. 하나만 쓰면 됩니다.

## 방법 1 — CLI로 등록 (가장 간단)

`tool/mcp-server` 디렉토리에서:

```bash
claude mcp add production-metrics -- python server.py
```

- `--` 뒤가 서버를 실행하는 명령입니다. venv를 쓴다면 `python` 대신
  venv의 파이썬 절대경로(예: `.venv/Scripts/python.exe`)를 주는 편이 안전합니다.
- 등록 확인·삭제:
  ```bash
  claude mcp list
  claude mcp get production-metrics
  claude mcp remove production-metrics
  ```

등록 범위(scope)를 지정할 수 있습니다:
```bash
claude mcp add production-metrics --scope project -- python server.py   # 이 프로젝트만 (.mcp.json 생성)
claude mcp add production-metrics --scope user    -- python server.py   # 내 모든 프로젝트
```

## 방법 2 — `.mcp.json` 파일로 등록 (팀 공유용)

프로젝트 루트에 `.mcp.json`을 두면 저장소를 클론한 팀원 모두가 같은 도구를 씁니다.
경로는 각자 환경에 맞게 조정하세요(절대경로 권장).

```json
{
  "mcpServers": {
    "production-metrics": {
      "command": "python",
      "args": ["tool/mcp-server/server.py"]
    }
  }
}
```

Claude Code를 다시 시작하면 이 서버를 인식합니다. 처음 로드 시 신뢰 여부를 물어볼 수 있습니다.

## 방법 3 — 원격(HTTP) 서버 (심화)

로컬 spawn이 아니라 이미 떠 있는 HTTP MCP 서버에 붙일 때:

```bash
claude mcp add my-remote --transport http https://mcp.example.com/mcp
```

## 사용 확인

등록 후 세션에서:

```
production-metrics 도구로 07-14 B라인 OEE를 구해줘.
```

- 도구가 보이지 않으면 `/mcp` 명령으로 연결 상태를 확인하세요.
- 모델이 OEE를 직접 암산하려 하면(도구를 안 부르면), "compute_oee 도구를 사용해서"라고
  명시하면 됩니다. 도구 설명(docstring)이 구체적일수록 자동 호출이 잘 됩니다.

## 자주 나는 오류

| 증상 | 원인 / 해결 |
|---|---|
| `spawn python ENOENT` | `python`이 PATH에 없음. 파이썬 절대경로로 등록. |
| 도구 목록에 안 뜸 | 등록 후 Claude Code 재시작 필요. `claude mcp list`로 먼저 확인. |
| `ModuleNotFoundError: mcp` | 서버를 실행하는 파이썬에 `pip install -r requirements.txt`가 안 됨 (venv 경로 확인). |
| 데이터 못 찾음 | server.py는 자기 위치 기준으로 `data/production.csv`를 찾음. 파일 이동 시 경로 수정. |
