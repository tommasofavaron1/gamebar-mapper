using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace ControllerMapper.Backend;

internal sealed class HighResolutionTimer : IDisposable
{
    private const uint CreateWaitableTimerHighResolution = 0x00000002;
    private const uint TimerAllAccess = 0x001F0003;
    private const uint WaitObject0 = 0x00000000;
    private readonly SafeWaitHandle? timer;

    public HighResolutionTimer()
    {
        var handle = CreateWaitableTimerEx(
            IntPtr.Zero,
            null,
            CreateWaitableTimerHighResolution,
            TimerAllAccess);
        if (!handle.IsInvalid)
        {
            timer = handle;
        }
        else
        {
            handle.Dispose();
        }
    }

    public void Wait(int milliseconds)
    {
        var dueTime = -milliseconds * 10_000L;
        if (timer is null ||
            !SetWaitableTimerEx(timer, ref dueTime, 0, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, 0) ||
            WaitForSingleObject(timer, uint.MaxValue) != WaitObject0)
        {
            Thread.Sleep(milliseconds);
        }
    }

    public void Dispose()
    {
        timer?.Dispose();
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeWaitHandle CreateWaitableTimerEx(
        IntPtr timerAttributes,
        string? timerName,
        uint flags,
        uint desiredAccess);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWaitableTimerEx(
        SafeWaitHandle timer,
        ref long dueTime,
        int period,
        IntPtr completionRoutine,
        IntPtr completionRoutineArgument,
        IntPtr wakeContext,
        uint tolerableDelay);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(SafeWaitHandle handle, uint milliseconds);
}