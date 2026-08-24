$ErrorActionPreference = "Stop"

$projectRoot = Split-Path $PSScriptRoot -Parent
$packageRoot = Get-ChildItem (Join-Path $projectRoot "AppPackages") -Directory |
    Where-Object Name -like "WidgetSampleCS_*_x64_Test" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName
$makeAppx = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Filter "makeappx.exe" -Recurse |
    Where-Object FullName -like "*\x64\makeappx.exe" |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
$iexpress = Join-Path $env:WINDIR "System32\iexpress.exe"
$stagingRoot = Join-Path $PSScriptRoot "staging"
$payloadRoot = Join-Path $stagingRoot "payload"
$packageLayout = Join-Path $payloadRoot "Package"
$dependenciesLayout = Join-Path $payloadRoot "Dependencies"
$companionLayout = Join-Path $payloadRoot "Companion"
$driversLayout = Join-Path $payloadRoot "Drivers"
$distRoot = Join-Path $projectRoot "dist"
$targetExe = Join-Path $distRoot "ControllerMapperSetup.exe"
$sedPath = Join-Path $stagingRoot "ControllerMapperSetup.sed"

& (Join-Path $projectRoot "build.cmd")
if ($LASTEXITCODE -ne 0) {
    throw "Compilazione Release non riuscita."
}

$packageRoot = Get-ChildItem (Join-Path $projectRoot "AppPackages") -Directory |
    Where-Object Name -like "WidgetSampleCS_*_x64_Test" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName
$msix = Get-ChildItem $packageRoot -Filter "*.msix" | Select-Object -First 1 -ExpandProperty FullName

if ([string]::IsNullOrWhiteSpace($makeAppx) -or
    [string]::IsNullOrWhiteSpace($msix) -or
    -not (Test-Path $iexpress)) {
    throw "MakeAppx, IExpress o il pacchetto MSIX Release non sono disponibili."
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

$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=
DisplayLicense=
FinishMessage=Controller Mapper installato. Apri Xbox Game Bar con Win+G.
TargetName=$targetExe
FriendlyName=Controller Mapper Setup
AppLaunched=powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
SourceFiles=SourceFiles
[SourceFiles]
SourceFiles0=$stagingRoot\
[SourceFiles0]
%FILE0%=
%FILE1%=
[Strings]
FILE0="install.ps1"
FILE1="payload.zip"
"@

Set-Content -Path $sedPath -Value $sed -Encoding ASCII
Remove-Item $targetExe -Force -ErrorAction SilentlyContinue
$iexpressProcess = Start-Process -FilePath $iexpress -ArgumentList "/N", $sedPath -Wait -PassThru
$minimumInstallerSize = 10MB
$targetFile = Get-Item $targetExe -ErrorAction SilentlyContinue

if ($null -eq $targetFile -or $targetFile.Length -lt $minimumInstallerSize) {
    $temporaryInstaller = Get-ChildItem $distRoot -Filter "RCX*.tmp" -File -ErrorAction SilentlyContinue |
        Where-Object Length -ge $minimumInstallerSize |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -ne $temporaryInstaller) {
        Move-Item $temporaryInstaller.FullName $targetExe -Force
        $targetFile = Get-Item $targetExe
    }
}

if ($iexpressProcess.ExitCode -ne 0 -or
    $null -eq $targetFile -or
    $targetFile.Length -lt $minimumInstallerSize) {
    throw "Creazione dell'installer EXE non riuscita."
}

Write-Output "INSTALLER=$targetExe"
