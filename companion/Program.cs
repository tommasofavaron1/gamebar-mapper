using System.Text.Json;
using Nefarius.ViGEm.Client;
using Nefarius.ViGEm.Client.Targets;
using Nefarius.ViGEm.Client.Targets.Xbox360;

namespace ControllerMapper.Backend;

internal static class Program
{
    private const string PackageFamilyName = "ControllerMapperWidget_fc9ae22wvwsv0";
    private static bool debugLogging;
    private static string? lastDebugStatus;
    private static XInputButtons lastDebugInput;
    private static XInputButtons lastDebugOutput;
    private static string? lastWrittenStatus;
    private static DateTime nextStatusWrite = DateTime.MinValue;
    private static readonly string LocalStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Packages",
        PackageFamilyName,
        "LocalState");
    private static readonly string ProfilePath = Path.Combine(LocalStatePath, "controller-profile.json");
    private static readonly string StatusPath = Path.Combine(LocalStatePath, "backend-status.json");
    private static readonly string DiagnosticPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "ControllerMapperWidget",
        "backend.log");

    public static async Task<int> Main(string[] args)
    {
        if (args.Contains("--self-test", StringComparer.OrdinalIgnoreCase))
        {
            return RunSelfTest();
        }

        debugLogging = args.Contains("--debug", StringComparer.OrdinalIgnoreCase);

        using var mutex = new Mutex(true, "Local\\ControllerMapperBackend", out var isFirstInstance);
        if (!isFirstInstance)
        {
            return 0;
        }

        try
        {
            Directory.CreateDirectory(LocalStatePath);
            await RunAsync();
            return 0;
        }
        catch (Exception exception)
        {
            WriteStartupFailure(exception);
            WriteStatus("startup-error", $"Backend startup failed: {exception.Message}");
            return 1;
        }
    }

    private static async Task RunAsync()
    {
        MappingProfile profile = new();
        DateTime profileWriteTime = DateTime.MinValue;
        ViGEmClient? client = null;
        IXbox360Controller? virtualController = null;
        var hidHide = new HidHideController();
        using var activeLoopTimer = new HighResolutionTimer();

        try
        {
            while (true)
            {
                if (File.Exists(ProfilePath))
                {
                    var currentWriteTime = File.GetLastWriteTimeUtc(ProfilePath);
                    if (currentWriteTime != profileWriteTime)
                    {
                        try
                        {
                            profile = MappingProfile.Load(ProfilePath);
                            profileWriteTime = currentWriteTime;
                        }
                        catch (IOException)
                        {
                        }
                        catch (JsonException)
                        {
                        }
                    }
                }

                if (!profile.Enabled)
                {
                    var hidHideError = hidHide.SetCloaking(false);
                    DisconnectVirtualController(ref virtualController);
                    WriteStatus(
                        hidHideError is null ? "disabled" : "hidhide-error",
                        hidHideError ?? "Rimappatura disattivata, controller fisico visibile");
                    await Task.Delay(100);
                    continue;
                }

                var physicalControllerIndex = (uint)Math.Clamp(profile.SelectedControllerIndex, 0, 3);
                if (!XInput.TryGetState(physicalControllerIndex, out var state))
                {
                    DisconnectVirtualController(ref virtualController);
                    WriteStatus("waiting", $"Controller {physicalControllerIndex + 1} non rilevato");
                    await Task.Delay(250);
                    continue;
                }

                if (virtualController is null)
                {
                    try
                    {
                        client ??= new ViGEmClient();
                        virtualController = client.CreateXbox360Controller();
                        virtualController.AutoSubmitReport = false;
                        virtualController.Connect();
                    }
                    catch (Exception exception)
                    {
                        WriteStatus("driver-error", exception.Message);
                        virtualController = null;
                        client?.Dispose();
                        client = null;
                        await Task.Delay(1000);
                        continue;
                    }
                }

                SubmitState(virtualController, state.Gamepad, profile);
                var cloakError = hidHide.SetCloaking(true);
                WriteStatus(
                    cloakError is null ? "active" : "hidhide-error",
                    cloakError is null
                        ? $"Controller fisico {physicalControllerIndex + 1} nascosto, output virtuale attivo"
                        : $"Output virtuale attivo, ma {cloakError}");
                activeLoopTimer.Wait(1);
            }
        }
        finally
        {
            hidHide.SetCloaking(false);
            DisconnectVirtualController(ref virtualController);
            client?.Dispose();
        }
    }

    private static void SubmitState(
        IXbox360Controller controller,
        XInputGamepad input,
        MappingProfile profile)
    {
        var mapped = MappingEngine.Apply(input, profile);

        if (debugLogging &&
            (input.Buttons != lastDebugInput || mapped.Buttons != lastDebugOutput))
        {
            Console.WriteLine($"Input: {input.Buttons,-20} -> Output: {mapped.Buttons}");
            lastDebugInput = input.Buttons;
            lastDebugOutput = mapped.Buttons;
        }

        foreach (var pair in ButtonMap)
        {
            controller.SetButtonState(pair.Value, (mapped.Buttons & pair.Key) != 0);
        }

        controller.SetSliderValue(Xbox360Slider.LeftTrigger, mapped.LeftTrigger);
        controller.SetSliderValue(Xbox360Slider.RightTrigger, mapped.RightTrigger);
        controller.SetAxisValue(Xbox360Axis.LeftThumbX, input.LeftThumbX);
        controller.SetAxisValue(Xbox360Axis.LeftThumbY, input.LeftThumbY);
        controller.SetAxisValue(Xbox360Axis.RightThumbX, input.RightThumbX);
        controller.SetAxisValue(Xbox360Axis.RightThumbY, input.RightThumbY);
        controller.SubmitReport();
    }

    private static readonly IReadOnlyDictionary<XInputButtons, Xbox360Button> ButtonMap =
        new Dictionary<XInputButtons, Xbox360Button>
        {
            [XInputButtons.DPadUp] = Xbox360Button.Up,
            [XInputButtons.DPadDown] = Xbox360Button.Down,
            [XInputButtons.DPadLeft] = Xbox360Button.Left,
            [XInputButtons.DPadRight] = Xbox360Button.Right,
            [XInputButtons.Menu] = Xbox360Button.Start,
            [XInputButtons.View] = Xbox360Button.Back,
            [XInputButtons.LeftThumbstick] = Xbox360Button.LeftThumb,
            [XInputButtons.RightThumbstick] = Xbox360Button.RightThumb,
            [XInputButtons.LeftShoulder] = Xbox360Button.LeftShoulder,
            [XInputButtons.RightShoulder] = Xbox360Button.RightShoulder,
            [XInputButtons.A] = Xbox360Button.A,
            [XInputButtons.B] = Xbox360Button.B,
            [XInputButtons.X] = Xbox360Button.X,
            [XInputButtons.Y] = Xbox360Button.Y
        };

    private static void DisconnectVirtualController(ref IXbox360Controller? controller)
    {
        if (controller is null)
        {
            return;
        }

        controller.Disconnect();
        controller = null;
    }

    private static void WriteStatus(string state, string message)
    {
        if (debugLogging)
        {
            var debugStatus = $"{state}: {message}";
            if (!string.Equals(lastDebugStatus, debugStatus, StringComparison.Ordinal))
            {
                Console.WriteLine(debugStatus);
                lastDebugStatus = debugStatus;
            }
        }

        var status = $"{state}:{message}";
        if (string.Equals(lastWrittenStatus, status, StringComparison.Ordinal) &&
            DateTime.UtcNow < nextStatusWrite)
        {
            return;
        }

        var temporaryPath = StatusPath + ".tmp";
        try
        {
            File.WriteAllText(temporaryPath, JsonSerializer.Serialize(new
            {
                state,
                message,
                updatedAt = DateTimeOffset.UtcNow
            }));
            File.Move(temporaryPath, StatusPath, true);
            lastWrittenStatus = status;
            nextStatusWrite = DateTime.UtcNow.AddSeconds(1);
        }
        catch (IOException)
        {
            File.Delete(temporaryPath);
        }
        catch (UnauthorizedAccessException)
        {
            File.Delete(temporaryPath);
        }
    }

    private static void WriteStartupFailure(Exception exception)
    {
        try
        {
            var diagnosticDirectory = Path.GetDirectoryName(DiagnosticPath)!;
            Directory.CreateDirectory(diagnosticDirectory);
            File.AppendAllText(
                DiagnosticPath,
                $"[{DateTimeOffset.Now:O}] {exception}{Environment.NewLine}");
        }
        catch (Exception)
        {
        }
    }

    private static int RunSelfTest()
    {
        var profile = new MappingProfile
        {
            Enabled = true,
            Mappings =
            [
                new MappingEntry { Source = "A", Target = "B" },
                new MappingEntry { Source = "X", Target = "Disabilitato" },
                new MappingEntry { Source = "Y", Target = "LeftTrigger" },
                new MappingEntry { Source = "LeftTrigger", Target = "RightTrigger" },
                new MappingEntry { Source = "RightTrigger", Target = "A" }
            ]
        };
        var input = new XInputGamepad
        {
            Buttons = XInputButtons.A | XInputButtons.X | XInputButtons.Y,
            LeftTrigger = 128,
            RightTrigger = 200
        };
        var result = MappingEngine.Apply(input, profile);
        var expectedButtons = XInputButtons.A | XInputButtons.B;

        if (result.Buttons != expectedButtons ||
            result.LeftTrigger != byte.MaxValue ||
            result.RightTrigger != 128)
        {
            Console.Error.WriteLine(
                $"Self-test fallito: ottenuti {result.Buttons}, LT={result.LeftTrigger}, RT={result.RightTrigger}");
            return 1;
        }

        Console.WriteLine("SELF_TEST_OK");
        return 0;
    }
}