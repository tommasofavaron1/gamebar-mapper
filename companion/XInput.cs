using System.Runtime.InteropServices;

namespace ControllerMapper.Backend;

[Flags]
internal enum XInputButtons : ushort
{
    DPadUp = 0x0001,
    DPadDown = 0x0002,
    DPadLeft = 0x0004,
    DPadRight = 0x0008,
    Menu = 0x0010,
    View = 0x0020,
    LeftThumbstick = 0x0040,
    RightThumbstick = 0x0080,
    LeftShoulder = 0x0100,
    RightShoulder = 0x0200,
    A = 0x1000,
    B = 0x2000,
    X = 0x4000,
    Y = 0x8000
}

[StructLayout(LayoutKind.Sequential)]
internal struct XInputGamepad
{
    public XInputButtons Buttons;
    public byte LeftTrigger;
    public byte RightTrigger;
    public short LeftThumbX;
    public short LeftThumbY;
    public short RightThumbX;
    public short RightThumbY;
}

[StructLayout(LayoutKind.Sequential)]
internal struct XInputState
{
    public uint PacketNumber;
    public XInputGamepad Gamepad;
}

internal static class XInput
{
    [DllImport("xinput1_4.dll", EntryPoint = "XInputGetState")]
    private static extern uint GetState(uint userIndex, out XInputState state);

    public static bool TryGetState(uint userIndex, out XInputState state)
    {
        return GetState(userIndex, out state) == 0;
    }

    public static uint? FindConnectedController()
    {
        for (uint index = 0; index < 4; index++)
        {
            if (TryGetState(index, out _))
            {
                return index;
            }
        }

        return null;
    }
}