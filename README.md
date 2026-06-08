Claude 설치
6. Claude 설치
```
irm https://claude.ai/install.ps1 | iex
```

7. 설치 확인 — 결과가 True 면 정상
```
Test-Path "$env:USERPROFILE\.local\bin\claude.exe"
```

9. 경로 추가 (필수) — 아래 네 줄을 그대로 붙여넣고 Enter
```
$claudePath = "$env:USERPROFILE\.local\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$claudePath*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$claudePath", "User")
}
```
