# Architettura

Controller Mapper e composto da un widget UWP, un backend desktop e due driver di terze parti.

## Flusso runtime

1. Il widget legge il controller con `Windows.Gaming.Input.Gamepad` e salva il profilo JSON nella `LocalState` del pacchetto.
2. Il backend osserva il profilo e legge il primo controller fisico disponibile tramite XInput.
3. `MappingEngine` trasforma pulsanti e trigger, conservando l'intensita analogica tra trigger.
4. ViGEmBus espone il risultato come controller Xbox 360 virtuale.
5. HidHide nasconde al gioco sia il nodo HID sia il nodo XInput del controller fisico.

Il backend e autorizzato da HidHide a vedere il dispositivo nascosto. Il controller virtuale viene escluso dal cloaking riconoscendo il parent `ROOT\\SYSTEM` e il container ViGEm `VID_045E&PID_028E`.

## Componenti

### Widget UWP

- `App.xaml.cs` gestisce l'attivazione `ms-gamebarwidget`.
- `Widget1.xaml` e `Widget1.xaml.cs` gestiscono interfaccia, input live e mapping.
- `ProfileStore` serializza `controller-profile.json`.
- `BackendStatusStore` legge `backend-status.json`.
- `Package.appxmanifest` registra `microsoft.gameBarUIExtension`.

### Companion desktop

- `XInput.cs` cerca i controller negli slot XInput da 0 a 3.
- `MappingEngine.cs` applica il profilo senza dipendere da UI o driver.
- `HidHideController.cs` attiva e disattiva il cloaking tramite la CLI ufficiale.
- `Program.cs` coordina profilo, input fisico, output ViGEm e stato condiviso.

### Installazione

- `build.cmd` compila il widget `Release|x64` con .NET Native.
- `install-dev.ps1` registra localmente il layout UWP per lo sviluppo.
- `configure-hidhide.ps1` seleziona e configura in modo conservativo il controller fisico.
- `installer/build-installer.ps1` produce l'installer IExpress standalone.
- `installer/install.ps1` installa driver, widget, backend e avvio automatico.

## Stato condiviso

I due processi comunicano tramite file nella directory:

```text
%LOCALAPPDATA%\Packages\ControllerMapperWidget_fc9ae22wvwsv0\LocalState
```

- `controller-profile.json`: profilo e stato della rimappatura.
- `backend-status.json`: stato operativo e ultimo aggiornamento del backend.

Le letture tollerano file assenti, dati non validi e contesa temporanea durante la scrittura.