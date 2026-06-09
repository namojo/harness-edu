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
