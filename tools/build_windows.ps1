$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotDirectory = Join-Path $projectRoot '.tools/godot-4.7.2'
$godot = Join-Path $godotDirectory 'Godot_v4.7.2-stable_win64_console.exe'
$template = Join-Path $godotDirectory 'templates/windows_release_x86_64.exe'
$project = Join-Path $projectRoot 'prototype'
$dist = Join-Path $projectRoot 'dist'
$package = Join-Path $dist 'windows-x64'
$executable = Join-Path $package 'SwarmAttack.exe'
$archive = Join-Path $dist 'SwarmAttack-Windows-x64.zip'
$licenses = Join-Path $package 'LICENCES-GODOT.txt'

foreach ($dependency in @($godot, $template)) {
    if (-not (Test-Path -LiteralPath $dependency -PathType Leaf)) {
        throw "Fichier manquant : $dependency"
    }
}
New-Item -ItemType Directory -Path $package -Force | Out-Null
$buildAppData = Join-Path $godotDirectory 'build-appdata'
New-Item -ItemType Directory -Path $buildAppData -Force | Out-Null
$originalAppData = $env:APPDATA

try {
    $env:APPDATA = $buildAppData
    & $godot --headless --editor --import --path $project
    if ($LASTEXITCODE -ne 0) {
        throw "Echec de l'import Godot ($LASTEXITCODE)."
    }
    & $godot --headless --path $project --script (Join-Path $PSScriptRoot 'godot_licenses.gd') -- $licenses
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $licenses)) {
        throw 'Export des licences Godot impossible.'
    }
    & $godot --headless --path $project --export-release 'Windows Desktop' $executable
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executable)) {
        throw "Echec de l'export Godot ($LASTEXITCODE)."
    }
} finally {
    $env:APPDATA = $originalAppData
}

$readme = Join-Path $package 'LISEZ-MOI.txt'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'windows_readme.txt') -Destination $readme -Force
Compress-Archive -LiteralPath @($executable, $readme, $licenses) -DestinationPath $archive -Force
Get-FileHash -LiteralPath $archive -Algorithm SHA256
