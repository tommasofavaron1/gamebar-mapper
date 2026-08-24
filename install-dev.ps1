$ErrorActionPreference = "Stop"

$packageRoot = Get-ChildItem (Join-Path $PSScriptRoot "AppPackages") -Directory |
    Where-Object Name -like "WidgetSampleCS_*_x64_Test" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName

if ([string]::IsNullOrWhiteSpace($packageRoot)) {
    throw "Cartella del pacchetto Release x64 non trovata. Eseguire prima build.cmd."
}

Get-ChildItem (Join-Path $packageRoot "Dependencies\x64") -Filter "*.appx" | ForEach-Object {
    try {
        Add-AppxPackage -Path $_.FullName -ForceApplicationShutdown
    }
    catch {
        if ($_.Exception.Message -notmatch "0x80073D06") {
            throw
        }
    }
}

$makeAppx = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Filter "makeappx.exe" -Recurse |
    Where-Object FullName -like "*\x64\makeappx.exe" |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
$msix = Get-ChildItem $packageRoot -Filter "*.msix" |
    Select-Object -First 1 -ExpandProperty FullName
$layout = Join-Path $PSScriptRoot "bin\x64\ReleasePackage"

if ([string]::IsNullOrWhiteSpace($makeAppx) -or [string]::IsNullOrWhiteSpace($msix)) {
    throw "MakeAppx o pacchetto MSIX Release non trovato."
}

$installed = Get-AppxPackage -Name "ControllerMapperWidget"
if ($null -ne $installed) {
    Remove-AppxPackage -Package $installed.PackageFullName -PreserveApplicationData
}

Remove-Item $layout -Recurse -Force -ErrorAction SilentlyContinue
& $makeAppx unpack /p $msix /d $layout /o
if ($LASTEXITCODE -ne 0) {
    throw "Estrazione del pacchetto Release non riuscita."
}

Add-AppxPackage -Register (Join-Path $layout "AppxManifest.xml")

$package = Get-AppxPackage -Name "ControllerMapperWidget"
if ($null -eq $package) {
    throw "Controller Mapper non risulta registrato."
}

Write-Output "REGISTERED=$($package.PackageFullName)"