$ErrorActionPreference = "Stop"

$packageName = "ControllerMapperWidget"
$installRoot = Join-Path $env:LOCALAPPDATA "Programs\ControllerMapperWidget"
$workingRoot = Join-Path $env:TEMP ("ControllerMapperWidget-" + [Guid]::NewGuid().ToString("N"))
$installId = [Guid]::NewGuid().ToString("N")
$logPath = Join-Path $env:TEMP "ControllerMapperWidget-install-$installId.log"
$programFiles64 = if ([string]::IsNullOrWhiteSpace(${env:ProgramW6432})) {
    $env:ProgramFiles
} else {
    ${env:ProgramW6432}
}

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
$isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdministrator) {
    $elevatedArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $elevatedProcess = Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList $elevatedArguments `
        -Verb RunAs `
        -Wait `
        -PassThru
    exit $elevatedProcess.ExitCode
}

try {
    Start-Transcript -Path $logPath -Force | Out-Null
    Expand-Archive -Path (Join-Path $PSScriptRoot "payload.zip") -DestinationPath $workingRoot -Force

    if ($null -eq (Get-Service "ViGEmBus" -ErrorAction SilentlyContinue)) {
        $driverSetup = Join-Path $workingRoot "Drivers\ViGEmBusSetup.exe"
        $driverProcess = Start-Process $driverSetup -ArgumentList "/passive", "/norestart" -Wait -PassThru
        if ($driverProcess.ExitCode -notin 0, 3010) {
            throw "Installazione ViGEmBus non riuscita: codice $($driverProcess.ExitCode)."
        }

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
            -Wait `
            -PassThru
        if ($hidHideProcess.ExitCode -notin 0, 3010) {
            throw "Installazione HidHide non riuscita: codice $($hidHideProcess.ExitCode)."
        }

        $hidHideCli = $hidHideCliCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($null -eq $hidHideCli) {
            throw "HidHide e stato installato ma HidHideCLI non e disponibile. Riavvia Windows e ripeti l'installazione."
        }
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

    $backendPath = Join-Path $installRoot "Companion\ControllerMapper.Backend.exe"
    Copy-Item (Join-Path $workingRoot "configure-hidhide.ps1") $installRoot -Force
    & (Join-Path $installRoot "configure-hidhide.ps1")
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    New-Item $runKey -Force | Out-Null
    New-ItemProperty `
        -Path $runKey `
        -Name "ControllerMapperBackend" `
        -Value "`"$backendPath`"" `
        -PropertyType String `
        -Force | Out-Null
    try {
        Start-Process "explorer.exe" -ArgumentList "`"$backendPath`""
        Start-Process "explorer.exe" -ArgumentList "ms-gamebar:"
    }
    catch {
        Write-Warning "Installazione completata, ma l'avvio automatico iniziale non e riuscito: $($_.Exception.Message)"
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
