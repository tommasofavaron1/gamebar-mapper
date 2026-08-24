# Controller Mapper for Xbox Game Bar

![Controller Mapper](Assets/StoreLogo.scale-200.png)

Controller Mapper e un widget per Xbox Game Bar che rimappa gli input di un controller XInput. Il widget gestisce i profili e mostra un'anteprima live; un companion desktop applica il mapping ai giochi tramite un controller Xbox 360 virtuale.

> Il progetto e in sviluppo e l'installer non e firmato digitalmente. ViGEmBus e HidHide sono driver di terze parti e la loro installazione richiede privilegi amministrativi.

## Funzionalita

- Widget ridimensionabile e fissabile in Xbox Game Bar.
- Mapping di pulsanti, trigger analogici, D-pad, dorsali, stick, Menu e View.
- Disabilitazione dei singoli pulsanti.
- Profili JSON persistenti e aggiornamento live del mapping.
- Anteprima indipendente dalla rimappatura reale.
- Output virtuale Xbox 360 tramite ViGEmBus.
- Eliminazione del doppio input tramite HidHide.

Con **Rimappatura ON**, il backend collega il controller virtuale e nasconde i nodi HID/XInput del controller fisico. Con **Rimappatura OFF**, scollega il virtuale e rende nuovamente visibile il controller fisico.

I mapping `LeftTrigger` e `RightTrigger` conservano l'intensita analogica quando l'uscita e un altro trigger. Un trigger associato a un pulsante usa la soglia XInput standard; un pulsante associato a un trigger produce una pressione completa.

## Requisiti

- Windows 10/11 x64 con Xbox Game Bar aggiornata.
- Visual Studio 2022 Community con il workload **Sviluppo piattaforma UWP**.
- Windows 10 SDK `10.0.18362.0`.
- .NET SDK 9.
- ViGEmBus `1.22.0` e HidHide `1.5.230.0` per la rimappatura reale.

## Sviluppo

Compilare e registrare il widget:

```powershell
.\build.cmd
powershell.exe -ExecutionPolicy Bypass -File .\install-dev.ps1
```

La build UWP usa `Release|x64` e .NET Native. Per lavorare rapidamente sul solo backend:

```powershell
dotnet build .\companion\ControllerMapper.Backend.csproj -c Debug -r win-x64
.\companion\bin\Debug\net9.0-windows\win-x64\ControllerMapper.Backend.exe --self-test
```

I comandi principali sono disponibili anche in **Terminal > Run Task** in VS Code.

## Configurazione HidHide

Dopo avere installato i driver e collegato un solo controller fisico, eseguire PowerShell come amministratore:

```powershell
.\configure-hidhide.ps1
```

Lo script registra il backend tra le applicazioni consentite, identifica il controller fisico ed esclude il controller virtuale ViGEm. Per evitare handle gia aperti, avviare o riavviare il gioco dopo una modifica alla configurazione HidHide.

## Installer

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\installer\build-installer.ps1
```

L'output viene creato in `dist\ControllerMapperSetup.exe`. La cartella `dist` non fa parte del repository: pubblicare l'EXE come asset di una GitHub Release.

## Struttura

- `Widget1.xaml`: interfaccia del widget Game Bar.
- `Models/` e `Services/`: profilo, persistenza e stato backend.
- `companion/`: lettura XInput, mapping, ViGEm e controllo HidHide.
- `installer/`: creazione e contenuto dell'installer standalone.
- `Assets/`: loghi e risorse visuali UWP.
- `ARCHITECTURE.md`: flusso dei dati e responsabilita dei componenti.

I profili e lo stato runtime sono salvati nella `LocalState` del pacchetto UWP e non vengono inclusi nel repository.