#========================================================
# "Power Management Service" — soundcharge.ps1
#========================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$cs = @'
using System;
using System.Text;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
public struct PropVariant {
    public ushort vt;
    ushort r1, r2, r3;
    public int intVal;
    int pad;
}

[StructLayout(LayoutKind.Sequential)]
public struct PropertyKey {
    public Guid fmtid;
    public int pid;
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
public class MMDeviceEnumeratorClass {}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(uint dataFlow, uint stateMask, out IntPtr ppDevices);
    int GetDefaultAudioEndpoint(uint dataFlow, uint role, out IMMDevice ppEndpoint);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDevice {
    int Activate(ref Guid iid, uint dwClsCtx, IntPtr pActivationParams,
        [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
    int OpenPropertyStore(int stgmAccess, out IPropertyStore ppProperties);
    int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
    int GetState(out uint pdwState);
}

[Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IPropertyStore {
    int GetCount(out uint cProps);
    int GetAt(uint iProp, out PropertyKey pkey);
    int GetValue(ref PropertyKey key, out PropVariant pv);
    int SetValue(ref PropertyKey key, ref PropVariant propvar);
    int Commit();
}

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAudioEndpointVolume {
    int RegisterControlChangeNotify(IntPtr pNotify);
    int UnregisterControlChangeNotify(IntPtr pNotify);
    int GetChannelCount(out int pnChannelCount);
    int SetMasterVolumeLevel(float fLevelDB, ref Guid pguidEventContext);
    int SetMasterVolumeLevelScalar(float fLevel, ref Guid pguidEventContext);
    int GetMasterVolumeLevel(out float pfLevelDB);
    int GetMasterVolumeLevelScalar(out float pfLevel);
    int SetChannelVolumeLevel(uint nChannel, float fLevelDB, ref Guid pguidEventContext);
    int SetChannelVolumeLevelScalar(uint nChannel, float fLevel, ref Guid pguidEventContext);
    int GetChannelVolumeLevel(uint nChannel, out float pfLevelDB);
    int GetChannelVolumeLevelScalar(uint nChannel, out float pfLevel);
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, ref Guid pguidEventContext);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
}

public static class AudioHelper {
    private static IAudioEndpointVolume GetVolumeInterface() {
        var e = (IMMDeviceEnumerator)new MMDeviceEnumeratorClass();
        IMMDevice d; e.GetDefaultAudioEndpoint(0, 1, out d);
        Guid g = typeof(IAudioEndpointVolume).GUID;
        object o; d.Activate(ref g, 23, IntPtr.Zero, out o);
        return (IAudioEndpointVolume)o;
    }

    public static float GetVolume() {
        try { float v; GetVolumeInterface().GetMasterVolumeLevelScalar(out v); return v; }
        catch { return 0.5f; }
    }

    public static void SetVolume(float level) {
        try {
            Guid empty = Guid.Empty;
            GetVolumeInterface().SetMasterVolumeLevelScalar(
                Math.Max(0f, Math.Min(1f, level)), ref empty);
        } catch {}
    }

    public static bool GetMute() {
        try { bool m; GetVolumeInterface().GetMute(out m); return m; }
        catch { return false; }
    }

    public static void SetMute(bool mute) {
        try {
            Guid empty = Guid.Empty;
            GetVolumeInterface().SetMute(mute, ref empty);
        } catch {}
    }

    public static bool IsHeadphones() {
        try {
            var e = (IMMDeviceEnumerator)new MMDeviceEnumeratorClass();
            IMMDevice d; e.GetDefaultAudioEndpoint(0, 1, out d);
            IPropertyStore p; d.OpenPropertyStore(0, out p);
            PropertyKey key = new PropertyKey();
            key.fmtid = new Guid("1da5d803-d492-4edd-8c23-e0c0ffee7f0e");
            key.pid = 0;
            PropVariant pv; p.GetValue(ref key, out pv);
            return pv.intVal == 3 || pv.intVal == 5;
        } catch { return false; }
    }
}

public static class MciPlayer {
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
    private static extern int mciSendStringW(string cmd, StringBuilder buf, int bufSz, IntPtr hwnd);

    private static int _counter = 0;

    public static string Play(string filePath) {
        string alias = "sc" + (_counter++);
        var sb = new StringBuilder(260);
        mciSendStringW("open \"" + filePath + "\" type mpegvideo alias " + alias, sb, 260, IntPtr.Zero);
        mciSendStringW("play " + alias, sb, 260, IntPtr.Zero);
        return alias;
    }

    public static int GetLengthMs(string alias) {
        var sb = new StringBuilder(64);
        mciSendStringW("status " + alias + " length", sb, 64, IntPtr.Zero);
        int ms; int.TryParse(sb.ToString(), out ms);
        return ms > 0 ? ms : 5000;
    }

    public static void Close(string alias) {
        mciSendStringW("close " + alias, null, 0, IntPtr.Zero);
    }
}
'@

Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Windows.Forms

# ── Resolve sounds folders ─────────────────────────────
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$plugDir   = Join-Path $scriptDir "sounds\plug"
$unplugDir = Join-Path $scriptDir "sounds\unplug"

$plugFiles = @()
$unplugFiles = @()
if (Test-Path $plugDir)   { $plugFiles   = @(Get-ChildItem -Path $plugDir   -Filter "*.mp3" -File | Select-Object -ExpandProperty FullName) }
if (Test-Path $unplugDir) { $unplugFiles = @(Get-ChildItem -Path $unplugDir -Filter "*.mp3" -File | Select-Object -ExpandProperty FullName) }
if ($plugFiles.Count -eq 0 -and $unplugFiles.Count -eq 0) { exit }

$rng = New-Object System.Random
$isPlaying = $false
$savedVolume = 0.5
$savedMute = $false
$wasMaxed = $false
$currentAlias = ""

# Track current power state
$lastPowerState = [System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus

# ── Play sound function ────────────────────────────────
function Play-Sound($fileList) {
    if ($script:isPlaying) { return }
    if ($fileList.Count -eq 0) { return }

    $script:isPlaying = $true
    $file = $fileList[$script:rng.Next($fileList.Count)]

    # Volume logic
    $headphones = [AudioHelper]::IsHeadphones()
    if (-not $headphones) {
        $script:savedVolume = [AudioHelper]::GetVolume()
        $script:savedMute = [AudioHelper]::GetMute()
        [AudioHelper]::SetMute($false)
        [AudioHelper]::SetVolume(1.0)
        $script:wasMaxed = $true
    } else {
        $script:wasMaxed = $false
    }

    $script:currentAlias = [MciPlayer]::Play($file)
    $lengthMs = [MciPlayer]::GetLengthMs($script:currentAlias)

    $script:restoreTimer.Interval = $lengthMs + 800
    $script:restoreTimer.Start()
}

# ── Hidden form + tray icon ────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.ShowInTaskbar = $false
$form.WindowState = 'Minimized'
$form.FormBorderStyle = 'FixedToolWindow'
$form.Opacity = 0
$form.Size = New-Object System.Drawing.Size(1, 1)

$trayIcon = New-Object System.Windows.Forms.NotifyIcon
try {
    $batPath = Join-Path $env:SystemRoot "System32\batmeter.dll"
    if (Test-Path $batPath) {
        $trayIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($batPath)
    } else {
        $trayIcon.Icon = [System.Drawing.SystemIcons]::Application
    }
} catch {
    $trayIcon.Icon = [System.Drawing.SystemIcons]::Application
}
$trayIcon.Text = "Windows Power Management Service"
$trayIcon.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$label1 = $menu.Items.Add("Power Management Service v1.2")
$label1.Enabled = $false
$label2 = $menu.Items.Add("Status: Monitoring")
$label2.Enabled = $false
$trayIcon.ContextMenuStrip = $menu

# ── Power check timer (every 1 second) ─────────────────
$powerTimer = New-Object System.Windows.Forms.Timer
$powerTimer.Interval = 1000
$powerTimer.Add_Tick({
    $currentState = [System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus

    if ($currentState -ne $script:lastPowerState) {
        if ($currentState -eq 'Online') {
            # Charger plugged in
            Play-Sound $script:plugFiles
        } else {
            # Charger unplugged
            Play-Sound $script:unplugFiles
        }
        $script:lastPowerState = $currentState
    }
})
$powerTimer.Start()

# ── Restore timer ──────────────────────────────────────
$restoreTimer = New-Object System.Windows.Forms.Timer
$restoreTimer.Interval = 5000
$restoreTimer.Add_Tick({
    $script:restoreTimer.Stop()
    if ($script:wasMaxed) {
        [AudioHelper]::SetVolume($script:savedVolume)
        [AudioHelper]::SetMute($script:savedMute)
        $script:wasMaxed = $false
    }
    if ($script:currentAlias -ne "") {
        [MciPlayer]::Close($script:currentAlias)
        $script:currentAlias = ""
    }
    $script:isPlaying = $false
})

$form.Add_FormClosed({
    $powerTimer.Stop()
    $restoreTimer.Stop()
    $trayIcon.Visible = $false
    $trayIcon.Dispose()
})

[System.Windows.Forms.Application]::Run($form)
