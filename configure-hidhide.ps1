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

    $registeredApplications = (& $hidHideCli --app-list | Out-String)
    if ($LASTEXITCODE -ne 0 -or
        $registeredApplications -notmatch [regex]::Escape($backendPath)) {
        throw "HidHide non ha confermato l'autorizzazione per $backendPath."
    }
}

function Test-ViGEmContainer {
    param([Parameter(Mandatory = $true)][string]$InstanceId)

    $currentId = $InstanceId
    $visitedIds = @{}

    for ($depth = 0; $depth -lt 16; $depth++) {
        if ([string]::IsNullOrWhiteSpace($currentId) -or
            $currentId -like "HTREE\*" -or
            $visitedIds.ContainsKey($currentId)) {
            break
        }

        $visitedIds[$currentId] = $true
        $properties = @(Get-PnpDeviceProperty -InstanceId $currentId -ErrorAction SilentlyContinue)
        $service = ($properties | Where-Object KeyName -eq "DEVPKEY_Device_Service" | Select-Object -First 1).Data
        $matchingDeviceId = ($properties | Where-Object KeyName -eq "DEVPKEY_Device_MatchingDeviceId" | Select-Object -First 1).Data

        if ($service -eq "ViGEmBus" -or $matchingDeviceId -like "Nefarius\ViGEmBus\*") {
            return $true
        }

        $currentId = ($properties | Where-Object KeyName -eq "DEVPKEY_Device_Parent" | Select-Object -First 1).Data
    }

    return $false
}

$gamingGroups = (& $hidHideCli --dev-gaming | Out-String | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0) {
    throw "Lettura dei controller gaming da HidHide non riuscita."
}

$gamingContainerIds = @($gamingGroups.devices |
    Where-Object {
        $_.present -and
        $_.gamingDevice -and
        -not [string]::IsNullOrWhiteSpace($_.baseContainerDeviceInstancePath)
    } |
    ForEach-Object { $_.baseContainerDeviceInstancePath } |
    Sort-Object -Unique)
$virtualContainerIds = @($gamingContainerIds | Where-Object { Test-ViGEmContainer $_ })

$physicalGamingDevices = @($gamingGroups | ForEach-Object {
        $friendlyName = $_.friendlyName
        $_.devices | Where-Object {
            $_.present -and
            $_.gamingDevice -and
            -not [string]::IsNullOrWhiteSpace($_.baseContainerDeviceInstancePath) -and
            $_.baseContainerDeviceInstancePath -notin $virtualContainerIds
        } | ForEach-Object {
            [pscustomobject]@{
                Name = $friendlyName
                InstanceId = $_.deviceInstancePath
                ContainerId = $_.baseContainerDeviceInstancePath
            }
        }
    })

$physicalControllerGroups = @($physicalGamingDevices | Group-Object ContainerId)
if ($physicalControllerGroups.Count -ne 1) {
    $physicalGamingDevices | Format-Table Name, InstanceId, ContainerId -AutoSize
    throw "Rilevati $($physicalControllerGroups.Count) controller fisici. Configurazione automatica annullata per sicurezza."
}

$physicalController = $physicalControllerGroups | Select-Object -First 1
$physicalDeviceIds = @($physicalController.Group.InstanceId | Sort-Object -Unique)
$physicalXInputIds = @(Get-PnpDevice -PresentOnly -Class XnaComposite -ErrorAction SilentlyContinue |
    ForEach-Object {
        $parent = (Get-PnpDeviceProperty `
            -InstanceId $_.InstanceId `
            -KeyName "DEVPKEY_Device_Parent" `
            -ErrorAction Stop).Data

        if ($parent -eq $physicalController.Name) {
            $_.InstanceId
        }
    })

$hiddenDeviceIds = @($physicalDeviceIds + $physicalXInputIds | Sort-Object -Unique)
foreach ($hiddenDeviceId in $hiddenDeviceIds) {
    & $hidHideCli --dev-hide $hiddenDeviceId
    if ($LASTEXITCODE -ne 0) {
        throw "Configurazione del nodo $hiddenDeviceId in HidHide non riuscita."
    }
}

$hiddenConfiguration = (& $hidHideCli --dev-list | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw "Verifica dei dispositivi nascosti da HidHide non riuscita."
}

foreach ($hiddenDeviceId in $hiddenDeviceIds) {
    if ($hiddenConfiguration -notmatch [regex]::Escape($hiddenDeviceId)) {
        throw "HidHide non ha confermato il nodo nascosto $hiddenDeviceId."
    }
}

& $hidHideCli --cloak-off
if ($LASTEXITCODE -ne 0) {
    throw "Disattivazione temporanea di HidHide non riuscita."
}

$cloakState = (& $hidHideCli --cloak-state | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $cloakState -ne "--cloak-off") {
    throw "HidHide non ha confermato la disattivazione temporanea del cloaking."
}

Write-Output "HIDHIDE_CONFIGURED=$($hiddenDeviceIds -join ',')"
Write-Output "Il controller resta visibile finche Rimappatura e disattivata."