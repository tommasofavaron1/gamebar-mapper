$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$installedBackend = Join-Path $env:LOCALAPPDATA "Programs\ControllerMapperWidget\Companion\ControllerMapper.Backend.exe"
$debugBackend = Join-Path $projectRoot "companion\bin\Debug\net9.0-windows\win-x64\ControllerMapper.Backend.exe"
$cliCandidates = @(
    (Join-Path $env:ProgramFiles "Nefarius Software Solutions\HidHide\HidHideCLI.exe"),
    (Join-Path $env:ProgramFiles "Nefarius Software Solutions\HidHide\x64\HidHideCLI.exe"),
    (Join-Path $env:ProgramFiles "Nefarius Software Solutions\HidHideCLI.exe")
)
$hidHideCli = $cliCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($null -eq $hidHideCli) {
    throw "HidHide non installato. Esegui tools\HidHide_1.5.230_x64.exe e riavvia Windows."
}

$backendPaths = @($installedBackend, $debugBackend) | Where-Object { Test-Path $_ }
foreach ($backendPath in $backendPaths) {
    & $hidHideCli --app-reg $backendPath
    if ($LASTEXITCODE -ne 0) {
        throw "Autorizzazione HidHide non riuscita per $backendPath."
    }
}

$virtualContainerIds = @(Get-PnpDevice -PresentOnly -Class XnaComposite -ErrorAction SilentlyContinue |
    ForEach-Object {
        $parent = (Get-PnpDeviceProperty `
            -InstanceId $_.InstanceId `
            -KeyName "DEVPKEY_Device_Parent" `
            -ErrorAction Stop).Data

        if ($parent -like "ROOT\SYSTEM\*") {
            $_.InstanceId
        }
    })

$gamingGroups = (& $hidHideCli --dev-gaming | Out-String | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0) {
    throw "Lettura dei controller gaming da HidHide non riuscita."
}

$physicalControllers = @($gamingGroups | ForEach-Object {
        $friendlyName = $_.friendlyName
        $_.devices | Where-Object {
            $_.present -and
            $_.gamingDevice -and
            $_.baseContainerDeviceInstancePath -notin $virtualContainerIds
        } | ForEach-Object {
            [pscustomobject]@{
                Name = $friendlyName
                InstanceId = $_.deviceInstancePath
                ContainerId = $_.baseContainerDeviceInstancePath
            }
        }
    })

if ($physicalControllers.Count -ne 1) {
    $physicalControllers | Format-Table Name, InstanceId, ContainerId -AutoSize
    throw "Rilevati $($physicalControllers.Count) controller fisici. Configurazione automatica annullata per sicurezza."
}

$physicalController = $physicalControllers | Select-Object -First 1
$physicalXInputIds = @(Get-PnpDevice -PresentOnly -Class XnaComposite -ErrorAction SilentlyContinue |
    ForEach-Object {
        $parent = (Get-PnpDeviceProperty `
            -InstanceId $_.InstanceId `
            -KeyName "DEVPKEY_Device_Parent" `
            -ErrorAction Stop).Data

        if ($parent -eq $physicalController.ContainerId) {
            $_.InstanceId
        }
    })

& $hidHideCli --dev-hide $physicalController.InstanceId
if ($LASTEXITCODE -ne 0) {
    throw "Configurazione del dispositivo HID fisico in HidHide non riuscita."
}

foreach ($physicalXInputId in $physicalXInputIds) {
    & $hidHideCli --dev-hide $physicalXInputId
    if ($LASTEXITCODE -ne 0) {
        throw "Configurazione del nodo XInput $physicalXInputId in HidHide non riuscita."
    }
}

& $hidHideCli --cloak-off
if ($LASTEXITCODE -ne 0) {
    throw "Disattivazione temporanea di HidHide non riuscita."
}

Write-Output "HIDHIDE_CONFIGURED=$($physicalController.InstanceId),$($physicalXInputIds -join ',')"
Write-Output "Il controller resta visibile finche Rimappatura e disattivata."