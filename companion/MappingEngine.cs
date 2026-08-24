namespace ControllerMapper.Backend;

internal static class MappingEngine
{
    private const byte TriggerButtonThreshold = 30;
    private static readonly IReadOnlyDictionary<string, XInputButtons> Buttons =
        Enum.GetValues<XInputButtons>().ToDictionary(button => button.ToString(), button => button);

    public static MappedGamepad Apply(XInputGamepad input, MappingProfile profile)
    {
        var mappings = profile.Mappings
            .Where(mapping => !string.IsNullOrWhiteSpace(mapping.Source))
            .GroupBy(mapping => mapping.Source)
            .ToDictionary(group => group.Key, group => group.Last().Target);
        var output = new MappedGamepad();

        foreach (var source in Buttons)
        {
            if ((input.Buttons & source.Value) == 0)
            {
                continue;
            }

            var targetName = mappings.TryGetValue(source.Key, out var configuredTarget)
                ? configuredTarget
                : source.Key;
            ApplyTarget(ref output, targetName, byte.MaxValue);
        }

        ApplyTarget(ref output, GetTarget(mappings, "LeftTrigger"), input.LeftTrigger);
        ApplyTarget(ref output, GetTarget(mappings, "RightTrigger"), input.RightTrigger);
        return output;
    }

    private static string GetTarget(IReadOnlyDictionary<string, string> mappings, string source)
    {
        return mappings.TryGetValue(source, out var target) ? target : source;
    }

    private static void ApplyTarget(ref MappedGamepad output, string targetName, byte intensity)
    {
        if (targetName == "LeftTrigger")
        {
            output.LeftTrigger = Math.Max(output.LeftTrigger, intensity);
        }
        else if (targetName == "RightTrigger")
        {
            output.RightTrigger = Math.Max(output.RightTrigger, intensity);
        }
        else if (intensity > TriggerButtonThreshold && Buttons.TryGetValue(targetName, out var target))
        {
            output.Buttons |= target;
        }
    }
}

internal struct MappedGamepad
{
    public XInputButtons Buttons;
    public byte LeftTrigger;
    public byte RightTrigger;
}