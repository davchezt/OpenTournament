[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Assert-LastExitCode {
    param([string]$Action)

    if ($LASTEXITCODE -ne 0) {
        throw "$Action failed with exit code $LASTEXITCODE."
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git was not found in PATH. Install Git and restart PowerShell."
}

& git lfs version | Out-Host
Assert-LastExitCode "Git LFS check"

$insideWorkTree = (& git rev-parse --is-inside-work-tree 2>$null)
Assert-LastExitCode "Git repository check"

if ($insideWorkTree.Trim() -ne "true") {
    throw "Run this script from inside an OpenTournament Git clone."
}

$repoRoot = (& git rev-parse --show-toplevel).Trim()
Assert-LastExitCode "Repository root lookup"

Push-Location $repoRoot

try {
    if (-not (Test-Path ".githooks/pre-push" -PathType Leaf)) {
        throw "Missing .githooks/pre-push. Ensure this is a current OpenTournament clone."
    }

    if (-not (Test-Path ".lfsconfig" -PathType Leaf)) {
        throw "Missing .lfsconfig. Ensure this is a current OpenTournament clone."
    }

    $existingHooksPath = (& git config --local --get core.hooksPath 2>$null)
    if ($LASTEXITCODE -notin @(0, 1)) {
        throw "Unable to read the existing core.hooksPath setting."
    }

    if (
        $existingHooksPath -and
        $existingHooksPath.Trim() -ne ".githooks" -and
        -not $Force
    ) {
        throw @"
This clone already has a different core.hooksPath:

  $($existingHooksPath.Trim())

Changing it could disable another repository-local hook setup.
Review that configuration, then rerun with -Force if replacing it is intentional:

  .\SetupContributor.ps1 -Force
"@
    }

    Write-Host "Configuring Git LFS filters for this clone..."
    & git lfs install --local --skip-repo
    Assert-LastExitCode "Git LFS configuration"

    Write-Host "Configuring shared OpenTournament Git hooks..."
    & git config --local core.hooksPath .githooks
    Assert-LastExitCode "Git hook configuration"

    $configuredHooksPath = (& git config --local --get core.hooksPath).Trim()
    Assert-LastExitCode "Git hook verification"

    $lfsUrl = (& git config --file .lfsconfig --get lfs.url).Trim()
    Assert-LastExitCode "Git LFS endpoint verification"

    $expectedLfsUrl = "https://git.opentournamentgame.com/opentournament/opentournament.git/info/lfs"

    if ($configuredHooksPath -ne ".githooks") {
        throw "Unexpected core.hooksPath value: $configuredHooksPath"
    }

    if ($lfsUrl -ne $expectedLfsUrl) {
        throw "Unexpected Git LFS endpoint: $lfsUrl"
    }

    Write-Host ""
    Write-Host "OpenTournament contributor setup is complete."
    Write-Host ""
    Write-Host "Git repository:"
    Write-Host "  GitHub forks, branches, and pull requests"
    Write-Host ""
    Write-Host "Git LFS storage:"
    Write-Host "  $lfsUrl"
    Write-Host ""
    Write-Host "Public users can download LFS files anonymously."
    Write-Host "Pushing new or modified LFS files requires GitLab contributor access."
    Write-Host ""
    Write-Host "When Git requests credentials for git.opentournamentgame.com:"
    Write-Host "  Username: your GitLab username"
    Write-Host "  Password: your GitLab personal access token"
    Write-Host ""
    Write-Host "Detailed instructions:"
    Write-Host "  docs/GIT_LFS.md"
    Write-Host ""
    Write-Host "Recommended verification:"
    Write-Host "  git lfs pull"
    Write-Host "  git lfs status"
}
finally {
    Pop-Location
}
