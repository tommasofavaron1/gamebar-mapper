$ErrorActionPreference = "Stop"

$projectRoot = Split-Path $PSScriptRoot -Parent
$manifest = [xml](Get-Content (Join-Path $projectRoot "Package.appxmanifest"))
$packageVersion = $manifest.Package.Identity.Version
$packageRoot = Join-Path $projectRoot "AppPackages\WidgetSampleCS_${packageVersion}_x64_Test"
$makeAppx = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Filter "makeappx.exe" -Recurse |
    Where-Object FullName -like "*\x64\makeappx.exe" |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
$innoCompiler = @(
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe")
) | Where-Object { Test-Path $_ } | Select-Object -First 1
$stagingRoot = Join-Path $PSScriptRoot "staging"
$payloadRoot = Join-Path $stagingRoot "payload"
$packageLayout = Join-Path $payloadRoot "Package"
$dependenciesLayout = Join-Path $payloadRoot "Dependencies"
$companionLayout = Join-Path $payloadRoot "Companion"
$driversLayout = Join-Path $payloadRoot "Drivers"
$distRoot = Join-Path $projectRoot "dist"
$targetExe = Join-Path $distRoot "ControllerMapperSetup.exe"
$issPath = Join-Path $stagingRoot "ControllerMapperSetup.iss"

& (Join-Path $projectRoot "build.cmd")
if ($LASTEXITCODE -ne 0) {
    throw "Compilazione Release non riuscita."
}

$msix = Get-ChildItem $packageRoot -Filter "*.msix" | Select-Object -First 1 -ExpandProperty FullName

if ([string]::IsNullOrWhiteSpace($makeAppx) -or
    [string]::IsNullOrWhiteSpace($msix) -or
    -not (Test-Path $innoCompiler)) {
    throw "MakeAppx, Inno Setup o il pacchetto MSIX Release non sono disponibili."
}

Remove-Item $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item $packageLayout -ItemType Directory -Force | Out-Null
New-Item $dependenciesLayout -ItemType Directory -Force | Out-Null
New-Item $companionLayout -ItemType Directory -Force | Out-Null
New-Item $driversLayout -ItemType Directory -Force | Out-Null
New-Item $distRoot -ItemType Directory -Force | Out-Null

& $makeAppx unpack /p $msix /d $packageLayout /o
if ($LASTEXITCODE -ne 0) {
    throw "Estrazione del pacchetto Release non riuscita."
}

Copy-Item (Join-Path $packageRoot "Dependencies\x64\*.appx") $dependenciesLayout -Force
dotnet publish (Join-Path $projectRoot "companion\ControllerMapper.Backend.csproj") `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o $companionLayout
if ($LASTEXITCODE -ne 0) {
    throw "Compilazione del companion non riuscita."
}

$driverSetup = Join-Path $driversLayout "ViGEmBusSetup.exe"
Invoke-WebRequest `
    -Uri "https://github.com/nefarius/ViGEmBus/releases/download/v1.22.0/ViGEmBus_1.22.0_x64_x86_arm64.exe" `
    -OutFile $driverSetup `
    -UseBasicParsing

$hidHideSetup = Join-Path $driversLayout "HidHideSetup.exe"
Invoke-WebRequest `
    -Uri "https://github.com/nefarius/HidHide/releases/download/v1.5.230.0/HidHide_1.5.230_x64.exe" `
    -OutFile $hidHideSetup `
    -UseBasicParsing
Copy-Item (Join-Path $projectRoot "configure-hidhide.ps1") $payloadRoot -Force

Compress-Archive -Path (Join-Path $payloadRoot "*") -DestinationPath (Join-Path $stagingRoot "payload.zip") -Force
Copy-Item (Join-Path $PSScriptRoot "install.ps1") $stagingRoot -Force

$iss = @"
[Setup]
AppId={{C1EC8EB8-E769-46A4-A62B-C5BDFB60A67C}
AppName=Controller Mapper
AppVersion=$packageVersion
AppPublisher=Controller Mapper
CreateAppDir=no
Uninstallable=no
PrivilegesRequired=lowest
OutputDir=$distRoot
OutputBaseFilename=ControllerMapperSetup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
DisableProgramGroupPage=yes

[Files]
Source: "$stagingRoot\install.ps1"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall
Source: "$stagingRoot\payload.zip"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{tmp}\install.ps1"""; StatusMsg: "Installazione di Controller Mapper..."; Flags: waituntilterminated
"@

Set-Content -Path $issPath -Value $iss -Encoding UTF8
Remove-Item $targetExe -Force -ErrorAction SilentlyContinue
& $innoCompiler /Qp $issPath
$minimumInstallerSize = 10MB
$targetFile = Get-Item $targetExe -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0 -or
    $null -eq $targetFile -or
    $targetFile.Length -lt $minimumInstallerSize) {
    throw "Creazione dell'installer EXE non riuscita."
}

Write-Output "INSTALLER=$targetExe"
