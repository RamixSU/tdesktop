#requires -Version 5.1
<#
Builds the phantom-economy Telegram Desktop for Windows x64, Release, and
packs a portable folder with the launcher.

Run it from the "x64 Native Tools Command Prompt for VS 2022":

    powershell -NoProfile -ExecutionPolicy Bypass -File windows\build-win.ps1

First run prepares every library (long, needs internet). Later runs reuse it.
#>
param(
    [switch]$SkipPrepare,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

if ($env:Platform -ne 'x64') {
    throw 'Run this from the "x64 Native Tools Command Prompt for VS 2022".'
}

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$root = Split-Path -Parent $repo
$libs = Join-Path $root 'Libraries\win64'
$out = Join-Path $repo 'out\Release'
$dist = Join-Path $root 'dist\Phantom-Telegram'

Write-Host "Repository: $repo"
Write-Host "Libraries:  $libs"

if (-not $SkipPrepare) {
    Write-Host 'Preparing libraries (this can take a long time)...'
    & cmd /c "`"$repo\Telegram\build\prepare\win.bat`" skip-release silent"
    if ($LASTEXITCODE -ne 0) {
        throw "prepare\win.bat failed with exit code $LASTEXITCODE"
    }
}

if (-not $SkipBuild) {
    Write-Host 'Configuring...'
    Push-Location (Join-Path $repo 'Telegram')
    try {
        $configureArgs = 'configure.bat x64 ' +
            '-D TDESKTOP_API_ID=611335 ' +
            '-D TDESKTOP_API_HASH=d524b414d21f4d37f08684c1df41ac9c ' +
            '-D CMAKE_CONFIGURATION_TYPES=Release ' +
            '-D DESKTOP_APP_DISABLE_AUTOUPDATE=ON ' +
            '-D DESKTOP_APP_DISABLE_CRASH_REPORTS=ON ' +
            '-D DESKTOP_APP_ENABLE_LTO=OFF'
        & cmd /c $configureArgs
        if ($LASTEXITCODE -ne 0) {
            throw "configure.bat failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }

    Write-Host 'Building Release...'
    cmake --build (Join-Path $repo 'out') --config Release --parallel
    if ($LASTEXITCODE -ne 0) {
        throw "cmake --build failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path (Join-Path $out 'Telegram.exe'))) {
    throw "Telegram.exe was not found in $out"
}

Write-Host "Packing $dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item (Join-Path $out '*.exe') $dist -Force
Get-ChildItem $out -Filter '*.dll' -ErrorAction SilentlyContinue |
    Copy-Item -Destination $dist -Force
Copy-Item (Join-Path $repo 'launcher\*') $dist -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $repo 'README.md') $dist -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'Done.'
Write-Host "Portable folder: $dist"
Write-Host 'Run PhantomLauncher.bat in that folder to start the client.'
