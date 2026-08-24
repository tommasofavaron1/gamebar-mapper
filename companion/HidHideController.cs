using System.Diagnostics;

namespace ControllerMapper.Backend;

internal sealed class HidHideController
{
    private static readonly string[] CliCandidates =
    [
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "Nefarius Software Solutions",
            "HidHide",
            "HidHideCLI.exe"),
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "Nefarius Software Solutions",
            "HidHide",
            "x64",
            "HidHideCLI.exe"),
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "Nefarius Software Solutions",
            "HidHideCLI.exe")
    ];

    private bool? currentState;

    public string? ConfigurePhysicalController()
    {
        var scriptPath = FindConfigurationScript();
        if (scriptPath is null)
        {
            return "Script di configurazione HidHide non trovato";
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.System),
                "WindowsPowerShell",
                "v1.0",
                "powershell.exe"),
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-ExecutionPolicy");
        startInfo.ArgumentList.Add("Bypass");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(scriptPath);

        using var process = Process.Start(startInfo);
        if (process is null)
        {
            return "Impossibile avviare la configurazione HidHide";
        }

        if (!process.WaitForExit(30000))
        {
            process.Kill(true);
            return "Configurazione HidHide non completata entro 30 secondi";
        }

        if (process.ExitCode != 0)
        {
            var error = process.StandardError.ReadToEnd().Trim();
            return string.IsNullOrWhiteSpace(error)
                ? $"Configurazione HidHide terminata con codice {process.ExitCode}"
                : error;
        }

        currentState = false;
        return null;
    }

    public string? SetCloaking(bool enabled)
    {
        if (currentState == enabled)
        {
            return null;
        }

        var cliPath = CliCandidates.FirstOrDefault(File.Exists);
        if (cliPath is null)
        {
            return "HidHide non installato";
        }

        using var process = Process.Start(new ProcessStartInfo
        {
            FileName = cliPath,
            Arguments = enabled
                ? "--cloak-on --cloak-state"
                : "--cloak-off --cloak-state",
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        });

        if (process is null)
        {
            return "Impossibile avviare HidHideCLI";
        }

        if (!process.WaitForExit(5000))
        {
            process.Kill(true);
            return "HidHideCLI non risponde";
        }

        if (process.ExitCode != 0)
        {
            var error = process.StandardError.ReadToEnd().Trim();
            return string.IsNullOrWhiteSpace(error)
                ? $"HidHideCLI ha restituito {process.ExitCode}"
                : error;
        }

        var reportedState = process.StandardOutput.ReadToEnd().Trim();
        var expectedState = enabled ? "--cloak-on" : "--cloak-off";
        if (!string.Equals(reportedState, expectedState, StringComparison.Ordinal))
        {
            return $"HidHide non ha confermato {expectedState}";
        }

        currentState = enabled;
        return null;
    }

    private static string? FindConfigurationScript()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        for (var depth = 0; depth < 8 && directory is not null; depth++)
        {
            var candidate = Path.Combine(directory.FullName, "configure-hidhide.ps1");
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        return null;
    }
}