param(
    [switch]$Elevated
)

$ErrorActionPreference = "Stop"

$packageName = "ControllerMapperWidget"
$installRoot = Join-Path $env:LOCALAPPDATA "Programs\ControllerMapperWidget"
$workingRoot = Join-Path $env:TEMP ("ControllerMapperWidget-" + [Guid]::NewGuid().ToString("N"))
$installId = [Guid]::NewGuid().ToString("N")
$logPath = Join-Path $env:TEMP "ControllerMapperWidget-install-$installId.log"
$driverRestartRequired = $false
$programFiles64 = if ([string]::IsNullOrWhiteSpace(${env:ProgramW6432})) {
    $env:ProgramFiles
} else {
    ${env:ProgramW6432}
}

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
$isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Start-UserComponents {
    $backendPath = Join-Path $installRoot "Companion\ControllerMapper.Backend.exe"
    $backendStatusPath = Join-Path $env:LOCALAPPDATA "Packages\ControllerMapperWidget_fc9ae22wvwsv0\LocalState\backend-status.json"
    if (-not (Test-Path $backendPath)) {
        throw "The Controller Mapper backend was not installed."
    }

    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    New-Item $runKey -Force | Out-Null
    New-ItemProperty `
        -Path $runKey `
        -Name "ControllerMapperBackend" `
        -Value "`"$backendPath`"" `
        -PropertyType String `
        -Force | Out-Null

    Get-Process "ControllerMapper.Backend" -ErrorAction SilentlyContinue | Stop-Process -Force
    Remove-Item $backendStatusPath -Force -ErrorAction SilentlyContinue
    $backendProcess = Start-Process -FilePath $backendPath -PassThru
    $backendReportedReady = $false
    for ($attempt = 0; $attempt -lt 12; $attempt++) {
        if ($backendProcess.WaitForExit(250)) {
            $backendLogPath = Join-Path $env:LOCALAPPDATA "ControllerMapperWidget\backend.log"
            throw "The Controller Mapper backend exited with code $($backendProcess.ExitCode). Log: $backendLogPath"
        }

        if (Test-Path $backendStatusPath) {
            $backendReportedReady = $true
            break
        }
    }

    if (-not $backendReportedReady) {
        Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
        throw "The Controller Mapper backend started but did not report its status."
    }

    Start-Process "ms-gamebar:"
}

if (-not $isAdministrator) {
    $elevatedArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated"
    $elevatedProcess = Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList $elevatedArguments `
        -Verb RunAs `
        -Wait `
        -PassThru
    if ($elevatedProcess.ExitCode -notin 0, 3010) {
        exit $elevatedProcess.ExitCode
    }

    $driverRestartRequired = $elevatedProcess.ExitCode -eq 3010
}

if ($Elevated -and -not $isAdministrator) {
    throw "Administrator privileges are required to install Controller Mapper."
}

try {
    Start-Transcript -Path $logPath -Force | Out-Null
    Expand-Archive -Path (Join-Path $PSScriptRoot "payload.zip") -DestinationPath $workingRoot -Force

    if (($Elevated -or $isAdministrator) -and
        $null -eq (Get-Service "ViGEmBus" -ErrorAction SilentlyContinue)) {
        $driverSetup = Join-Path $workingRoot "Drivers\ViGEmBusSetup.exe"
        $driverProcess = Start-Process $driverSetup -ArgumentList "/passive", "/norestart" -Wait -PassThru
        if ($driverProcess.ExitCode -notin 0, 3010) {
            throw "Installazione ViGEmBus non riuscita: codice $($driverProcess.ExitCode)."
        }

        $driverRestartRequired = $driverRestartRequired -or $driverProcess.ExitCode -eq 3010

        if ($null -eq (Get-Service "ViGEmBus" -ErrorAction SilentlyContinue)) {
            $driverRoot = Join-Path $programFiles64 "Nefarius Software Solutions\ViGEm Bus Driver"
            $nefcon = Join-Path $driverRoot "nefconw.exe"
            $driverInf = Join-Path $driverRoot "ViGEmBus.inf"

            if (-not (Test-Path $nefcon) -or -not (Test-Path $driverInf)) {
                throw "ViGEmBus ha copiato i file incompleti e non puo essere riparato automaticamente."
            }

            $registerProcess = Start-Process `
                -FilePath $nefcon `
                -ArgumentList "--install-driver", "--inf-path", "`"$driverInf`"" `
                -Wait `
                -PassThru
            if ($registerProcess.ExitCode -ne 0) {
                throw "Registrazione del driver ViGEmBus non riuscita: codice $($registerProcess.ExitCode)."
            }

            $deviceProcess = Start-Process `
                -FilePath $nefcon `
                -ArgumentList `
                    "--create-device-node", `
                    "--hardware-id", "Nefarius\ViGEmBus\Gen1", `
                    "--class-name", "System", `
                    "--class-guid", "{4D36E97D-E325-11CE-BFC1-08002BE10318}" `
                -Wait `
                -PassThru
            if ($deviceProcess.ExitCode -ne 0) {
                throw "Creazione del dispositivo ViGEmBus non riuscita: codice $($deviceProcess.ExitCode)."
            }
        }

        if ($null -eq (Get-Service "ViGEmBus" -ErrorAction SilentlyContinue)) {
            throw "Il servizio ViGEmBus non risulta installato dopo la configurazione del driver."
        }
    }

    if ($Elevated -or $isAdministrator) {
        $hidHideCliCandidates = @(
            (Join-Path $programFiles64 "Nefarius Software Solutions\HidHide\HidHideCLI.exe"),
            (Join-Path $programFiles64 "Nefarius Software Solutions\HidHide\x64\HidHideCLI.exe"),
            (Join-Path $programFiles64 "Nefarius Software Solutions\HidHideCLI.exe")
        )
        $hidHideCli = $hidHideCliCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($null -eq $hidHideCli) {
            $hidHideSetup = Join-Path $workingRoot "Drivers\HidHideSetup.exe"
            $hidHideProcess = Start-Process `
                -FilePath $hidHideSetup `
                -ArgumentList "/install", "/quiet", "/norestart", "INSTALLLEVEL=2" `
                -Wait `
                -PassThru
            if ($hidHideProcess.ExitCode -notin 0, 3010) {
                throw "Installazione HidHide non riuscita: codice $($hidHideProcess.ExitCode)."
            }

            $driverRestartRequired = $driverRestartRequired -or $hidHideProcess.ExitCode -eq 3010

            $hidHideCli = $hidHideCliCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($null -eq $hidHideCli) {
                if ($driverRestartRequired) {
                    Write-Warning "HidHide completera l'installazione dopo il riavvio di Windows."
                }
                else {
                    throw "HidHide e stato installato ma HidHideCLI non e disponibile."
                }
            }
        }

        if ($null -ne $hidHideCli) {
            & $hidHideCli --version | Out-Null
            if ($LASTEXITCODE -ne 0) {
                if ($driverRestartRequired) {
                    Write-Warning "HidHide non e ancora operativo e richiede il riavvio di Windows."
                }
                else {
                    throw "HidHideCLI e presente ma non riesce a comunicare con il driver."
                }
            }
        }
    }

    if ($Elevated) {
        if ($driverRestartRequired) {
            exit 3010
        }

        exit 0
    }

    Get-ChildItem (Join-Path $workingRoot "Dependencies") -Filter "*.appx" | ForEach-Object {
        try {
            Add-AppxPackage -Path $_.FullName -ForceApplicationShutdown
        }
        catch {
            if ($_.Exception.Message -notmatch "0x80073D06") {
                throw
            }
        }
    }

    Get-Process "ControllerMapper.Backend", "WidgetSampleCS" -ErrorAction SilentlyContinue | Stop-Process -Force
    $installed = Get-AppxPackage -Name $packageName
    if ($null -ne $installed) {
        Remove-AppxPackage -Package $installed.PackageFullName -PreserveApplicationData
    }

    Remove-Item $installRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item $installRoot -ItemType Directory -Force | Out-Null
    Copy-Item (Join-Path $workingRoot "Package\*") $installRoot -Recurse -Force
    Copy-Item (Join-Path $workingRoot "Companion") $installRoot -Recurse -Force
    Add-AppxPackage -Register (Join-Path $installRoot "AppxManifest.xml")

    $package = Get-AppxPackage -Name $packageName
    if ($null -eq $package -or $package.Status -ne "Ok") {
        throw "Il pacchetto Controller Mapper non risulta installato correttamente."
    }

    $hidHideConfigurationWarning = $null
    Copy-Item (Join-Path $workingRoot "configure-hidhide.ps1") $installRoot -Force
    if ($driverRestartRequired) {
        $hidHideConfigurationWarning = "Riavvia Windows, collega un solo controller e riesegui l'installer per completare la configurazione HidHide."
    }
    else {
        try {
            & (Join-Path $installRoot "configure-hidhide.ps1")
        }
        catch {
            $hidHideConfigurationWarning = $_.Exception.Message
        }
    }

    if ($null -ne $hidHideConfigurationWarning) {
        Write-Warning "HidHide configuration was skipped: $hidHideConfigurationWarning"
    }

    Start-UserComponents

    if ($null -ne $hidHideConfigurationWarning) {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            "Controller Mapper was installed and the backend is running, but HidHide could not be configured automatically.`n`n$hidHideConfigurationWarning`n`nConnect one controller and run configure-hidhide.ps1 from:`n$installRoot",
            "Controller Mapper Setup",
            "OK",
            "Warning") | Out-Null
    }
}
catch {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Installazione non riuscita.`n`n$($_.Exception.Message)`n`nLog: $logPath",
        "Controller Mapper Setup",
        "OK",
        "Error") | Out-Null
    exit 1
}
finally {
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    Remove-Item $workingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
