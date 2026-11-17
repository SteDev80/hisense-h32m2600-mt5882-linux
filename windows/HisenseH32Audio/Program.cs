using Microsoft.Win32;
using NAudio.CoreAudioApi;
using NAudio.Wave;
using System.Net;
using System.Net.Sockets;

namespace HisenseH32Audio;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        if (args.Contains("--test-tone"))
        {
            TestTone();
            return;
        }
        ApplicationConfiguration.Initialize();
        using var app = new TrayApplication();
        Application.Run();
    }

    private static void TestTone()
    {
        using var devices = new MMDeviceEnumerator();
        var endpoint = devices.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active)
            .FirstOrDefault(d => d.FriendlyName.Contains("VB-Audio Virtual Cable", StringComparison.OrdinalIgnoreCase)
                              && !d.FriendlyName.Contains("16 Ch", StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException("Uscita VB-Audio non trovata");
        var format = endpoint.AudioClient.MixFormat;
        var provider = new BufferedWaveProvider(format);
        var bytesPerFrame = format.BlockAlign;
        var samples = new byte[format.SampleRate * bytesPerFrame];
        for (var frame = 0; frame < format.SampleRate; frame++)
        {
            var wave = Math.Sin(2 * Math.PI * 440 * frame / format.SampleRate) * 0.06;
            for (var channel = 0; channel < format.Channels; channel++)
            {
                var offset = frame * bytesPerFrame + channel * (format.BitsPerSample / 8);
                if (format.BitsPerSample == 32)
                    BitConverter.GetBytes((float)wave).CopyTo(samples, offset);
                else if (format.BitsPerSample == 16)
                    BitConverter.GetBytes((short)(wave * short.MaxValue)).CopyTo(samples, offset);
            }
        }
        provider.AddSamples(samples, 0, samples.Length);
        using var output = new WasapiOut(endpoint, AudioClientShareMode.Shared, true, 100);
        output.Init(provider);
        output.Play();
        Thread.Sleep(1200);
    }
}

internal sealed class TrayApplication : IDisposable
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunName = "HisenseH32Audio";
    private readonly NotifyIcon tray;
    private readonly ToolStripMenuItem status;
    private readonly ToolStripMenuItem automatic;
    private WasapiCapture? capture;
    private WaveFormat? captureFormat;
    private UdpClient? udp;
    private readonly List<byte> pending = [];
    private static readonly string LogPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "HisenseH32Audio", "status.log");

    public TrayApplication()
    {
        status = new ToolStripMenuItem("Stato: fermo") { Enabled = false };
        automatic = new ToolStripMenuItem("Avvia con Windows") { CheckOnClick = true, Checked = AutoStartEnabled() };
        automatic.CheckedChanged += (_, _) => SetAutoStart(automatic.Checked);
        var menu = new ContextMenuStrip();
        menu.Items.Add(status);
        menu.Items.Add("Avvia streaming", null, (_, _) => Start());
        menu.Items.Add("Ferma streaming", null, (_, _) => Stop());
        menu.Items.Add(automatic);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Esci", null, (_, _) => { Stop(); Application.Exit(); });
        tray = new NotifyIcon
        {
            Icon = SystemIcons.Information,
            Text = "Hisense H32 Audio",
            ContextMenuStrip = menu,
            Visible = true
        };
        tray.DoubleClick += (_, _) => Toggle();
        Start();
    }

    private void Toggle()
    {
        if (capture is null) Start(); else Stop();
    }

    private void Start()
    {
        if (capture is not null) return;
        try
        {
            using var devices = new MMDeviceEnumerator();
            var endpoint = devices.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active)
                .FirstOrDefault(d => d.FriendlyName.Contains("VB-Audio Virtual Cable", StringComparison.OrdinalIgnoreCase)
                                  && !d.FriendlyName.Contains("16 Ch", StringComparison.OrdinalIgnoreCase));
            if (endpoint is null)
                throw new InvalidOperationException("CABLE Input non trovato. Installa o riavvia VB-Audio Virtual Cable.");

            udp = new UdpClient(AddressFamily.InterNetwork);
            udp.MulticastLoopback = true;
            capture = new WasapiLoopbackCapture(endpoint);
            captureFormat = capture.WaveFormat;
            if (captureFormat.SampleRate != 48000)
                throw new InvalidOperationException($"Imposta CABLE Output a 48000 Hz (ora {captureFormat.SampleRate} Hz).");
            capture.DataAvailable += SendAudio;
            capture.RecordingStopped += (_, e) =>
            {
                if (e.Exception is not null) ShowError(e.Exception.Message);
            };
            capture.StartRecording();
            Log($"RUNNING endpoint={endpoint.FriendlyName} format={captureFormat}");
            status.Text = "Stato: attivo → TV 239.255.77.77:4010";
            tray.Text = "Hisense H32 Audio – attivo";
            tray.ShowBalloonTip(2500, "Hisense H32 Audio", "Streaming verso la TV avviato", ToolTipIcon.Info);
        }
        catch (Exception e)
        {
            Log("ERROR " + e);
            Stop();
            ShowError(e.Message);
        }
    }

    private void SendAudio(object? sender, WaveInEventArgs e)
    {
        if (udp is null) return;
        lock (pending)
        {
            pending.AddRange(ConvertToPcm16(e.Buffer, e.BytesRecorded));
            const int audioBytes = 1152;
            while (pending.Count >= audioBytes)
            {
                var packet = new byte[audioBytes + 5];
                packet[0] = 1;   // 48 kHz
                packet[1] = 16;  // signed 16 bit
                packet[2] = 2;   // stereo
                packet[3] = 3;   // front left + front right
                packet[4] = 0;
                pending.CopyTo(0, packet, 5, audioBytes);
                pending.RemoveRange(0, audioBytes);
                udp.Send(packet, packet.Length, new IPEndPoint(IPAddress.Parse("239.255.77.77"), 4010));
            }
        }
    }

    private byte[] ConvertToPcm16(byte[] source, int length)
    {
        var format = captureFormat ?? throw new InvalidOperationException("Formato audio non disponibile");
        var sourceBytes = format.BitsPerSample / 8;
        var frames = length / format.BlockAlign;
        var result = new byte[frames * 4];
        for (var frame = 0; frame < frames; frame++)
        {
            for (var outputChannel = 0; outputChannel < 2; outputChannel++)
            {
                var inputChannel = Math.Min(outputChannel, format.Channels - 1);
                var inputOffset = frame * format.BlockAlign + inputChannel * sourceBytes;
                short value;
                if (format.BitsPerSample == 32)
                {
                    var sample = Math.Clamp(BitConverter.ToSingle(source, inputOffset), -1f, 1f);
                    value = (short)(sample * short.MaxValue);
                }
                else if (format.BitsPerSample == 16)
                {
                    value = BitConverter.ToInt16(source, inputOffset);
                }
                else
                {
                    throw new InvalidOperationException($"Formato VB-Audio non supportato: {format}");
                }
                var outputOffset = frame * 4 + outputChannel * 2;
                result[outputOffset] = (byte)value;
                result[outputOffset + 1] = (byte)(value >> 8);
            }
        }
        return result;
    }

    private void Stop()
    {
        try { capture?.StopRecording(); } catch { }
        capture?.Dispose();
        capture = null;
        captureFormat = null;
        udp?.Dispose();
        udp = null;
        lock (pending) pending.Clear();
        status.Text = "Stato: fermo";
        tray.Text = "Hisense H32 Audio – fermo";
    }

    private static bool AutoStartEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue(RunName) is string;
    }

    private static void SetAutoStart(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey);
        if (enabled)
            key.SetValue(RunName, $"\"{Environment.ProcessPath}\"");
        else
            key.DeleteValue(RunName, false);
    }

    private static void ShowError(string message) =>
        MessageBox.Show(message, "Hisense H32 Audio", MessageBoxButtons.OK, MessageBoxIcon.Error);

    private static void Log(string message)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(LogPath)!);
        File.AppendAllText(LogPath, $"{DateTime.Now:O} {message}{Environment.NewLine}");
    }

    public void Dispose()
    {
        Stop();
        tray.Visible = false;
        tray.Dispose();
    }
}
