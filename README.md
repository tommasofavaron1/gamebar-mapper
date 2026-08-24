# Controller Mapper for Xbox Game Bar

![Controller Mapper](Assets/StoreLogo.scale-200.png)

Controller Mapper is an Xbox Game Bar widget that remaps input from an XInput controller. The widget manages profiles and shows a live preview, while a desktop companion applies the mappings to games through a virtual Xbox 360 controller.

> This project is under development and the installer is not digitally signed. ViGEmBus and HidHide are third-party drivers, and installing them requires administrator privileges.

## Features

- Resizable and pinnable Xbox Game Bar widget.
- Mapping for buttons, analog triggers, D-pad, bumpers, sticks, Menu, and View.
- Individual button disabling.
- Persistent JSON profiles and live mapping updates.
- Preview independent from the active remapping output.
- Virtual Xbox 360 output through ViGEmBus.
- Double-input prevention through HidHide.

With **Remapping ON**, the backend connects the virtual controller and hides the physical controller's HID/XInput nodes. With **Remapping OFF**, it disconnects the virtual controller and makes the physical controller visible again.

`LeftTrigger` and `RightTrigger` mappings preserve analog intensity when the output is another trigger. A trigger mapped to a button uses the standard XInput threshold, while a button mapped to a trigger produces a full press.

## Requirements

- Windows 10/11 x64 with an up-to-date Xbox Game Bar.
- Visual Studio 2022 Community with the **Universal Windows Platform development** workload.
- Windows 10 SDK `10.0.18362.0`.
- .NET SDK 9.
- ViGEmBus `1.22.0` and HidHide `1.5.230.0` for actual input remapping.

## Development

Build and register the widget:

```powershell
.\build.cmd
powershell.exe -ExecutionPolicy Bypass -File .\install-dev.ps1
```

The UWP build uses `Release|x64` and .NET Native. To work on the backend only:

```powershell
dotnet build .\companion\ControllerMapper.Backend.csproj -c Debug -r win-x64
.\companion\bin\Debug\net9.0-windows\win-x64\ControllerMapper.Backend.exe --self-test
```

The main commands are also available from **Terminal > Run Task** in VS Code.

## HidHide Configuration

If the Controller Mapper installer reports an error while installing HidHide, download and install [HidHide 1.5.230](https://github.com/nefarius/HidHide/releases/download/v1.5.230.0/HidHide_1.5.230_x64.exe) manually. Restart Windows if prompted, then run the Controller Mapper installer again.

After installing the drivers and connecting a single physical controller, run PowerShell as an administrator:

```powershell
.\configure-hidhide.ps1
```

The script registers the backend as an allowed application, identifies the physical controller, and excludes the virtual ViGEm controller. To avoid handles that were already open, start or restart the game after changing the HidHide configuration.

## Installer

Building the installer requires [Inno Setup 6](https://jrsoftware.org/isinfo.php), which can be installed with:

```powershell
winget install --id JRSoftware.InnoSetup --exact
```

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\installer\build-installer.ps1
```

The output is created at `dist\ControllerMapperSetup.exe`. The `dist` directory is not part of the repository; publish the EXE as a GitHub Release asset.

## Project Structure

- `Widget1.xaml`: Game Bar widget interface.
- `Models/` and `Services/`: profiles, persistence, and backend state.
- `companion/`: XInput reading, mappings, ViGEm, and HidHide control.
- `installer/`: standalone installer creation and contents.
- `Assets/`: logos and UWP visual assets.
- `ARCHITECTURE.md`: data flow and component responsibilities.

Profiles and runtime state are stored in the UWP package's `LocalState` and are not included in the repository.