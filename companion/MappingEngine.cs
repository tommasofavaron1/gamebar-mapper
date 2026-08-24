namespace ControllerMapper.Backend;

internal static class MappingEngine
{
    private static readonly IReadOnlyDictionary<string, XInputButtons> Buttons =
        Enum.GetValues<XInputButtons>().ToDictionary(button => button.ToString(), button => button);

    public static XInputButtons Apply(XInputButtons pressedButtons, MappingProfile profile)
    {
        var mappings = profile.Mappings
            .Where(mapping => !string.IsNullOrWhiteSpace(mapping.Source))
            .GroupBy(mapping => mapping.Source)
            .ToDictionary(group => group.Key, group => group.Last().Target);
        var output = (XInputButtons)0;

        foreach (var source in Buttons)
        {
            if ((pressedButtons & source.Value) == 0)
            {
                continue;
            }

            var targetName = mappings.TryGetValue(source.Key, out var configuredTarget)
                ? configuredTarget
                : source.Key;
            if (Buttons.TryGetValue(targetName, out var target))
            {
                output |= target;
            }
        }

        return output;
    }
}