# Workshop Setup — Windows
# Usage: .\setup-windows.ps1 [-WSL2] [-WezTerm] [-Docker] [-Force]
# Run PowerShell as Administrator before executing.
param(
    [switch]$WSL2,
    [switch]$WezTerm,
    [switch]$Docker,
    [switch]$Force
)

$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ── Execution policy guard ────────────────────────────────────────────────────
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -ne 'RemoteSigned' -and $currentPolicy -ne 'Unrestricted') {
    Write-Host "  ⚠️  Execution policy is '$currentPolicy' — changing to 'RemoteSigned'..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
        Write-Host "  ✅  Execution policy set to 'RemoteSigned'" -ForegroundColor Green
    } catch {
        Write-Host "  ❌  Failed to set execution policy: $_" -ForegroundColor Red
        Write-Host "     Run manually as Administrator:" -ForegroundColor Yellow
        Write-Host "     Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned" -ForegroundColor Yellow
        exit 1
    }
}

# ── Admin check ───────────────────────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")
if (-not $isAdmin) {
    Write-Host "  ⚠️  관리자 권한으로 실행되지 않았습니다." -ForegroundColor Yellow
    Write-Host "     winget, WSL2 등 일부 설치에서 오류가 발생할 수 있습니다." -ForegroundColor Yellow
    Write-Host "     권장: PowerShell을 관리자 권한으로 재실행하세요." -ForegroundColor Yellow
    Write-Host ""
}

# ── Preflight checks ──────────────────────────────────────────────────────────
# Internet
Write-Host "  🔍  Preflight checks..." -ForegroundColor Cyan
try {
    $null = Test-NetConnection -ComputerName 1.1.1.1 -Port 443 -WarningAction SilentlyContinue -ErrorAction Stop
    Write-Host "  ✅  인터넷 연결 정상" -ForegroundColor Green
} catch {
    Write-Host "  ❌  인터넷에 연결할 수 없습니다. 네트워크를 확인하고 다시 시도하세요." -ForegroundColor Red
    exit 1
}

# Disk space (5 GB minimum)
$driveName = $PWD.Drive.Name
$freeSpace = (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue).Free
if ($freeSpace -and $freeSpace -lt 5368709120) {
    Write-Host ("  ❌  디스크 여유 공간 부족 ({0:N1} GB / 5 GB 필요)" -f ($freeSpace / 1GB)) -ForegroundColor Red
    exit 1
} elseif ($freeSpace) {
    Write-Host ("  ✅  디스크 여유 공간: {0:N1} GB" -f ($freeSpace / 1GB)) -ForegroundColor Green
}

# OS version
$osVersion = [Environment]::OSVersion.Version
$osBuild = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).CurrentBuild
if ($osBuild -and [int]$osBuild -lt 22000) {
    Write-Host ("  ⚠️  Windows 11 권장. 현재 빌드: $osBuild (Windows 10)" -f $osVersion.Major) -ForegroundColor Yellow
} else {
    Write-Host "  ✅  OS 버전 확인 완료" -ForegroundColor Green
}

# ── Animation helpers ─────────────────────────────────────────────────────────
$SpinChars = [char[]]@(0x280B, 0x2819, 0x2839, 0x2838, 0x283C, 0x2834, 0x2826, 0x2827, 0x2807, 0x280F)
$Errors    = [System.Collections.Generic.List[string]]::new()

function Section($num, $total, $label) {
    $pct    = [math]::Round($num * 100 / $total)
    $width  = 22
    $filled = [math]::Round($width * $pct / 100)
    if ($filled -lt 0)      { $filled = 0 }
    if ($filled -gt $width) { $filled = $width }
    $bar    = ('█' * $filled) + ('░' * ($width - $filled))
    Write-Host ""
    Write-Host ("[{0}/{1}] {2,-32} [{3}] {4,3}%" -f $num, $total, $label, $bar, $pct) -ForegroundColor Cyan
}

function RunStep($label, [scriptblock]$block) {
    $job = Start-Job -ScriptBlock $block
    $i   = 0
    while ($job.State -eq 'Running') {
        $ch = $SpinChars[$i % $SpinChars.Count]
        # PadRight로 뒤를 공백으로 채워 이전 프레임의 잔여 문자를 덮어쓴다.
        Write-Host (("`r  $ch  $label").PadRight(70)) -NoNewline -ForegroundColor Cyan
        $i++
        Start-Sleep -Milliseconds 80
    }
    $null = Receive-Job $job -Wait -ErrorAction SilentlyContinue
    $ok   = ($job.ChildJobs[0].JobStateInfo.State -eq 'Completed') -and ($job.ChildJobs[0].Error.Count -eq 0)

    if ($ok) {
        Write-Host (("`r✅  $label").PadRight(70)) -ForegroundColor Green
    } else {
        # Show last 5 error lines for debugging
        $errOutput = $job.ChildJobs[0].Error | ForEach-Object { $_.ToString() } | Select-Object -First 5
        if ($errOutput) {
            foreach ($line in $errOutput) {
                Write-Host "     $line" -ForegroundColor DarkGray
            }
        }
        $stdErr = $job.ChildJobs[0].Error
        if (-not $errOutput -and $stdErr) {
            $stdErrStr = $stdErr | Select-Object -First 1 | ForEach-Object { $_.Exception.Message }
            if ($stdErrStr) { Write-Host "     $stdErrStr" -ForegroundColor DarkGray }
        }
        Write-Host (("`r❌  $label").PadRight(70)) -ForegroundColor Red
        $Errors.Add($label)
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return $ok
}

function Installed($cmd) {
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function ShouldInstall($cmd) {
    return (-not (Installed $cmd)) -or $Force
}

function RefreshEnv {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

# ── Log setup ────────────────────────────────────────────────────────────────
$LogDir  = "$env:USERPROFILE\workshop-setup-logs"
$LogFile = Join-Path $LogDir "setup-windows-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
try {
    Start-Transcript -Path $LogFile -Append -ErrorAction Stop | Out-Null
    $transcriptStarted = $true
} catch {
    Write-Host "  ⚠️  로그 저장을 시작할 수 없습니다 (trans 실패): $_" -ForegroundColor Yellow
    $transcriptStarted = $false
}

# ── Graceful shutdown on Ctrl+C ──────────────────────────────────────────────
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
} -ErrorAction SilentlyContinue

# ── Header ────────────────────────────────────────────────────────────────────
Clear-Host
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     Workshop Setup — Windows              ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($Force) {
    Write-Host "  🔧  Force mode: all tools will be reinstalled" -ForegroundColor Yellow
    Write-Host ""
}

$TOTAL = 9

try {
# ════════════════════════════════════════════════════════════════════════════════
# MAIN BODY — wrapped in try/finally for graceful shutdown
# ════════════════════════════════════════════════════════════════════════════════

# ── 1. winget ─────────────────────────────────────────────────────────────────
Section 1 $TOTAL "winget"
if (Installed winget) {
    Write-Host "  ℹ️  winget found — updating sources & checking for upgrades..." -ForegroundColor DarkGray

    # winget 출력은 로케일(한글/영문)에 따라 헤더·요약 문구가 달라진다.
    # 기존 코드는 'Name'/'Id'/'upgrades available' 같은 영문 문자열을 전제로
    # 파싱해 한글 Windows에서는 헤더/요약 줄을 패키지로 오인하거나 목록을
    # 아예 잡지 못했다. 그래서 파싱에 의존하지 않고 winget 자체 기능으로
    # 전체 업그레이드를 수행한다(로케일 독립적, 신뢰성 우선).
    #  --include-unknown : 현재 버전을 알 수 없는 패키지도 업그레이드 대상에 포함
    #  --all             : 업그레이드 가능한 모든 패키지 처리
    Write-Host "  🔄  Refreshing winget sources..." -ForegroundColor DarkGray
    winget source update --accept-source-agreements *>&1 | Out-Null

    Write-Host "  ⬆️   Upgrading all packages (this may take a while)..." -ForegroundColor Cyan
    # 콘솔 출력은 Start-Transcript 가 로그로 캡처한다. 여기서 별도 파일에
    # Tee 하면 Transcript 가 잡고 있는 로그 파일과 잠금 충돌이 날 수 있어
    # 콘솔로만 흘려보낸다(--silent 라 출력은 최소).
    winget upgrade --all --include-unknown --silent `
        --accept-source-agreements --accept-package-agreements
    $wingetExit = $LASTEXITCODE

    # winget 종료코드 해석 (RunStep 을 쓰지 않는 이유: "업그레이드할 항목 없음"이
    # 비-0 코드로 반환되어 거짓 실패로 집계되기 때문).
    #   0            : 정상 완료
    #   -1978335189  : No applicable upgrade found (업그레이드할 항목 없음) — 정상
    if ($wingetExit -eq 0 -or $wingetExit -eq -1978335189) {
        Write-Host "✅  All winget packages up to date" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Some packages may not have upgraded (exit $wingetExit) — see log" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌  winget not found. Install 'App Installer' from the Microsoft Store." -ForegroundColor Red
    exit 1
}

RefreshEnv

# ── 2. PowerShell 7+ ─────────────────────────────────────────────────────────
Section 2 $TOTAL "PowerShell 7+"
$pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
$pwshVersion = if ($pwshPath) { & pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null } else { $null }
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "✅  PowerShell $($PSVersionTable.PSVersion) (already installed)" -ForegroundColor Green
} elseif ((-not $Force) -and $pwshVersion) {
    Write-Host "✅  PowerShell $pwshVersion (already installed — relaunch terminal as pwsh to use it)" -ForegroundColor Green
} else {
    RunStep "Install PowerShell 7+" {
        winget install Microsoft.PowerShell --silent --accept-source-agreements
    }
    RefreshEnv
    Write-Host "  ⚠️  Restart terminal with PowerShell 7 and re-run after install." -ForegroundColor Yellow
}

# ── 3. Terminal apps ──────────────────────────────────────────────────────────
Section 3 $TOTAL "Terminal apps"
if ((-not $Force) -and (Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue)) {
    Write-Host "✅  Windows Terminal (already installed)" -ForegroundColor Green
} else {
    RunStep "Install Windows Terminal" {
        winget install Microsoft.WindowsTerminal --silent --accept-source-agreements
    }
}
if ($WezTerm) {
    if ((-not $Force) -and (Installed wezterm)) {
        Write-Host "✅  WezTerm (already installed)" -ForegroundColor Green
    } else {
        RunStep "Install WezTerm" {
            winget install wez.wezterm --silent --accept-source-agreements
        }
    }
}

# ── 4. Git (+ Git Bash) + gh ──────────────────────────────────────────────────
Section 4 $TOTAL "Git + Git Bash + gh"
if ((-not $Force) -and (Installed git)) {
    Write-Host "✅  git $(git --version) (already installed)" -ForegroundColor Green
} else {
    RunStep "Install Git for Windows" {
        winget install Git.Git --silent --accept-source-agreements
    }
    RefreshEnv
}
if ((-not $Force) -and (Installed gh)) {
    Write-Host "✅  gh $(gh --version | Select-Object -First 1) (already installed)" -ForegroundColor Green
} else {
    RunStep "Install GitHub CLI" {
        winget install GitHub.cli --silent --accept-source-agreements
    }
    RefreshEnv
}
if ($WSL2) {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    if ($wslFeature -and $wslFeature.State -eq 'Enabled' -and -not $Force) {
        Write-Host "✅  WSL2 (already enabled)" -ForegroundColor Green
    } else {
        RunStep "Enable WSL2" { wsl --install }
        Write-Host "  ⚠️  Restart Windows to finish WSL2 setup." -ForegroundColor Yellow
    }
}

# ── 5. Runtime: bun ───────────────────────────────────────────────────────────
Section 5 $TOTAL "Runtime: bun"
if ((-not $Force) -and (Installed bun)) {
    Write-Host "✅  bun $(bun --version) (already installed)" -ForegroundColor Green
} else {
    $bunInstallScript = irm bun.sh/install.ps1
    Invoke-Expression $bunInstallScript
    # Permanent PATH registration (User scope)
    $bunBinPath = "$env:USERPROFILE\.bun\bin"
    $existingUserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($existingUserPath -notlike "*$bunBinPath*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$existingUserPath;$bunBinPath", "User")
    }
    RefreshEnv
    if (Installed bun) {
        Write-Host "✅  bun installed" -ForegroundColor Green
    } else {
        Write-Host "❌  bun install failed" -ForegroundColor Red
        $Errors.Add("Install bun")
    }
}

# ── 6. Runtime: python3 ───────────────────────────────────────────────────────
Section 6 $TOTAL "Runtime: python3"
if ((-not $Force) -and (Installed python)) {
    Write-Host "✅  $(python --version) (already installed)" -ForegroundColor Green
} else {
    RunStep "Install Python 3" {
        winget install Python.Python.3.13 --silent --accept-source-agreements
    }
    RefreshEnv
}

# ── 7. Runtime: uv ───────────────────────────────────────────────────────────
Section 7 $TOTAL "Runtime: uv"
if ((-not $Force) -and (Installed uv)) {
    Write-Host "✅  uv $(uv --version) (already installed)" -ForegroundColor Green
} else {
    RunStep "Install uv" {
        winget install --id astral-sh.uv --silent --accept-source-agreements
    }
    RefreshEnv
    if (-not (Installed uv)) {
        RunStep "Install uv (fallback)" {
            irm https://astral.sh/uv/install.ps1 | iex
        }
        RefreshEnv
    }
}

# ── 8. CLI tools ──────────────────────────────────────────────────────────────
Section 8 $TOTAL "CLI tools"
if ((-not $Force) -and (Installed claude)) {
    Write-Host "✅  claude (already installed)" -ForegroundColor Green
} else {
    $claudeInstalled = RunStep "Install Claude Code CLI" { bun install -g @anthropic-ai/claude-code }
    if (-not $claudeInstalled) {
        RunStep "Install Claude Code CLI (npm fallback)" { npm install -g @anthropic-ai/claude-code }
        RefreshEnv
    }
}
if ((-not $Force) -and (Installed agy)) {
    Write-Host "✅  agy (already installed)" -ForegroundColor Green
} else {
    RunStep "Install Antigravity CLI" {
        irm https://antigravity.google/cli/install.ps1 | iex
    }
    RefreshEnv
}

# ── 9. Desktop apps ───────────────────────────────────────────────────────────
Section 9 $TOTAL "Desktop apps"
if ((-not $Force) -and (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe")) {
    Write-Host "✅  Google Chrome (already installed)" -ForegroundColor Green
} else {
    RunStep "Install Google Chrome" {
        winget install Google.Chrome --silent --accept-source-agreements
    }
}
if ((-not $Force) -and (Test-Path "$env:LOCALAPPDATA\Programs\Claude\Claude.exe")) {
    Write-Host "✅  Claude Desktop (already installed)" -ForegroundColor Green
} else {
    RunStep "Install Claude Desktop" {
        winget install Anthropic.Claude --silent --accept-source-agreements
    }
}
Write-Host "  ⚠️  Antigravity Desktop — install manually: https://antigravity.google" -ForegroundColor Yellow
Write-Host "  ⚠️  Mark (Markdown viewer) — install manually: https://playloom.app/mark" -ForegroundColor Yellow
if ($Docker) {
    if ((-not $Force) -and (Installed docker)) {
        Write-Host "✅  Docker $(docker --version) (already installed)" -ForegroundColor Green
    } else {
        RunStep "Install Docker Desktop" {
            winget install Docker.DockerDesktop --silent --accept-source-agreements
        }
        Write-Host "  ⚠️  Launch Docker Desktop once to complete setup." -ForegroundColor Yellow
    }
}

# ── Git config check ──────────────────────────────────────────────────────────
$gitName  = git config --global user.name  2>$null
$gitEmail = git config --global user.email 2>$null
if ($gitName -and $gitEmail) {
    Write-Host "✅  git config: $gitName <$gitEmail>" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  git user not configured" -ForegroundColor Yellow
    Write-Host "       git config --global user.name 'Your Name'" -ForegroundColor DarkGray
    Write-Host "       git config --global user.email 'you@example.com'" -ForegroundColor DarkGray
}
$null = gh auth status 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅  gh auth: logged in" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  gh auth: not logged in — run 'gh auth login' before the workshop" -ForegroundColor Yellow
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ══════════════════════════════════════════" -ForegroundColor Cyan
if ($Errors.Count -eq 0) {
    Write-Host "  ✅  All steps complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Next → bun setup-common.ts" -ForegroundColor Cyan
} else {
    Write-Host ("  ❌  Failed: " + ($Errors -join ", ")) -ForegroundColor Red
}
Write-Host "  ══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ════════════════════════════════════════════════════════════════════════════════
} finally {
    # Graceful cleanup on Ctrl+C or error
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
    Write-Host "  📝  Log saved: $LogFile" -ForegroundColor DarkGray
}
