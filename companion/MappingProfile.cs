using System.Text.Json;

namespace ControllerMapper.Backend;

internal sealed class MappingProfile
{
    public bool Enabled { get; set; }

    public List<MappingEntry> Mappings { get; set; } = [];

    public static MappingProfile Load(string path)
    {
        using var stream = File.OpenRead(path);
        return JsonSerializer.Deserialize<MappingProfile>(stream) ?? new MappingProfile();
    }
}

internal sealed class MappingEntry
{
    public string Source { get; set; } = string.Empty;

    public string Target { get; set; } = string.Empty;
}