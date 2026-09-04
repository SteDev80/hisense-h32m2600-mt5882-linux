using System.Diagnostics;
using System.IO.Ports;
using System.Text;
using System.Text.RegularExpressions;

namespace H32BootSelector;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new BootSelectorForm());
    }
}

internal sealed class BootSelectorForm : Form
{
    private const string KernelFile = "uImage-h32m2600-rescue-initrd";
    private const string BootstrapFile = "uInitrd-h32m2600-bootstrap";
    private const string KernelAddress = "0x00007fc0";
    private const string InitrdAddress = "0x04000000";

    private const string BaseBootArgs =
        "console=ttyMT0,115200n1 earlyprintk loglevel=8 ignore_loglevel rdinit=/init vmalloc=700mb " +
        "mtdparts=mt53xx-emmc:2M(uboot),2M(uboot_env),256k(part_02),256k(part_03),4M(kernelA),4M(kernelB),75M(rootfsA),75M(rootfsB),256k(basic),8M(perm),320M(3rd_ro),750M(rw_area),256k(reserved),256k(channelA),256k(channelB),256k(pq),256k(aq),75M(logo),256k(ci),256k(part_19),3M(adsp),256k(ci),256k(dvbsDB),256k(hdcp),1M(facs),256k(hiscfg),2048M(data) " +
        "usbportusing=1,1,1,1 usbpwrgpio=-1:-1,-1:-1,-1:-1,-1:-1 usbocgpio=404:0,404:0,405:0,405:0 " +
        "usbhubrstgpio=-1:-1 msdcgpio=-1,-1,-1,-1,-1,-1 tzsz=18m no_console_suspend " +
        "gpustart=810270720 gpusize=0 gpuionsize=0";

    private readonly ComboBox _ports = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 110 };
    private readonly Button _refresh = new() { Text = "Aggiorna porte", AutoSize = true };
    private readonly Button _buildroot = new() { Text = "Avvia Buildroot (p27)", Width = 245, Height = 56 };
    private readonly Button _arch = new() { Text = "Avvia Arch sperimentale (USB)", Width = 245, Height = 56 };
    private readonly Label _status = new() { Text = "TV spenta: scegli il sistema, poi accendila.", AutoSize = true };
    private readonly CheckBox _usbVendor = new() { Text = "Variante USB con driver recuperati (p27 non montata)", AutoSize = true };
    private readonly TextBox _log = new()
    {
        Multiline = true,
        ReadOnly = true,
        ScrollBars = ScrollBars.Both,
        WordWrap = false,
        Dock = DockStyle.Fill,
        Font = new Font("Consolas", 9F)
    };

    private SerialPort? _serial;

    public BootSelectorForm()
    {
        Text = "Hisense H32M2600 - Selettore Linux";
        Width = 820;
        Height = 620;
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(720, 500);

        var title = new Label
        {
            Text = "Hisense H32M2600 / MediaTek MT5882",
            Font = new Font(Font.FontFamily, 16F, FontStyle.Bold),
            AutoSize = true
        };
        var note = new Label
        {
            Text = "Collega TTL e chiavetta. Il programma modifica solo variabili temporanee in RAM: non usa saveenv.",
            AutoSize = true,
            MaximumSize = new Size(760, 0)
        };
        var portRow = new FlowLayoutPanel { AutoSize = true, FlowDirection = FlowDirection.LeftToRight };
        portRow.Controls.Add(new Label { Text = "Porta TTL:", AutoSize = true, Padding = new Padding(0, 7, 0, 0) });
        portRow.Controls.Add(_ports);
        portRow.Controls.Add(_refresh);

        var buttons = new FlowLayoutPanel { AutoSize = true, FlowDirection = FlowDirection.LeftToRight };
        buttons.Controls.Add(_buildroot);
        buttons.Controls.Add(_arch);

        var top = new FlowLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            Padding = new Padding(14)
        };
        top.Controls.Add(title);
        top.Controls.Add(note);
        top.Controls.Add(portRow);
        top.Controls.Add(buttons);
        top.Controls.Add(_usbVendor);
        top.Controls.Add(_status);

        Controls.Add(_log);
        Controls.Add(top);

        _refresh.Click += (_, _) => RefreshPorts();
        _buildroot.Click += async (_, _) => await BootAsync("buildroot");
        _arch.Click += async (_, _) => await BootAsync("arch");
        _usbVendor.CheckedChanged += (_, _) =>
        {
            _buildroot.Text = _usbVendor.Checked ? "Avvia Buildroot USB + driver" : "Avvia Buildroot (p27)";
        };
        FormClosing += (_, _) => _serial?.Dispose();
        Shown += (_, _) => RefreshPorts();
    }

    private void RefreshPorts()
    {
        var previous = _ports.SelectedItem?.ToString();
        var names = SerialPort.GetPortNames().OrderBy(x => x).ToArray();
        _ports.Items.Clear();
        _ports.Items.AddRange(names);
        var preferred = names.FirstOrDefault(x => x.Equals(previous, StringComparison.OrdinalIgnoreCase))
                        ?? names.FirstOrDefault(x => x.Equals("COM3", StringComparison.OrdinalIgnoreCase))
                        ?? names.FirstOrDefault();
        if (preferred is not null) _ports.SelectedItem = preferred;
        _status.Text = names.Length == 0 ? "Nessuna porta TTL rilevata." : "TV spenta: scegli il sistema, poi accendila.";
    }

    private async Task BootAsync(string mode)
    {
        if (_ports.SelectedItem is not string portName)
        {
            MessageBox.Show("Collega l'adattatore TTL e premi Aggiorna porte.", "Porta TTL assente");
            return;
        }

        SetBusy(true);
        _log.Clear();
        try
        {
            _serial = new SerialPort(portName, 115200, Parity.None, 8, StopBits.One)
            {
                Handshake = Handshake.None,
                DtrEnable = false,
                RtsEnable = false,
                ReadTimeout = 100,
                WriteTimeout = 3000
            };
            _serial.Open();
            SetStatus($"In attesa dell'accensione per {ModeName(mode)}...");
            AppendLog("Collegamento TTL pronto. Accendi ora la TV.\r\n");

            var prompt = await WaitForUbootPromptAsync(TimeSpan.FromMinutes(30));
            if (!Regex.IsMatch(prompt, @"mt5882\s*#\s*$"))
                throw new InvalidOperationException("Prompt U-Boot non intercettato.");

            SetStatus("U-Boot intercettato; inizializzo la chiavetta...");
            await Task.Delay(TimeSpan.FromSeconds(10));
            var usb = await RunUbootAsync("usb start", TimeSpan.FromSeconds(60));
            Require(usb.Contains("1 Storage Device(s) found"), "Chiavetta Lexar non rilevata.");

            var kernel = await RunUbootAsync($"fatload usb 0:1 {KernelAddress} {KernelFile}", TimeSpan.FromMinutes(2));
            Require(kernel.Contains("5027136 bytes read"), "Kernel caricato in modo incompleto.");

            var bootstrap = _usbVendor.Checked ? "uInitrd-h32m2600-usb-vendor-v1" : BootstrapFile;
            var bootstrapSize = _usbVendor.Checked ? 1977369 : 1975736;
            var initrd = await RunUbootAsync($"fatload usb 0:1 {InitrdAddress} {bootstrap}", TimeSpan.FromMinutes(2));
            Require(initrd.Contains($"{bootstrapSize} bytes read"), "Bootstrap caricato in modo incompleto.");

            Require((await RunUbootAsync($"iminfo {KernelAddress}", TimeSpan.FromSeconds(45))).Contains("Verifying Checksum ... OK"), "CRC kernel non valido.");
            Require((await RunUbootAsync($"iminfo {InitrdAddress}", TimeSpan.FromSeconds(45))).Contains("Verifying Checksum ... OK"), "CRC bootstrap non valido.");

            var bootArgs = $"{BaseBootArgs} h32mode={mode}";
            if (_usbVendor.Checked) bootArgs += " h32root=usb h32vendor=1";
            await RunUbootAsync("setenv bootargs " + bootArgs, TimeSpan.FromSeconds(30));
            var env = await RunUbootAsync("printenv bootargs", TimeSpan.FromSeconds(30));
            Require(env.Contains($"h32mode={mode}"), "Modalità scelta non presente nei bootargs.");

            SetStatus($"Avvio {ModeName(mode)}...");
            WriteSerial($"bootm {KernelAddress} {InitrdAddress}\r");
            var expected = mode == "arch" ? "=== ARCH LINUX ARM EXPERIMENTAL MODE ===" : "=== BUILDROOT P27 MODE ===";
            if (_usbVendor.Checked && mode == "buildroot") expected = "=== BUILDROOT USB VENDOR MODE ===";
            var bootLog = await ReadUntilAsync(text => text.Contains(expected) && text.Contains("=== MT5882 BUILDROOT RESCUE READY ==="), TimeSpan.FromMinutes(8));
            Require(bootLog.Contains(expected), "Il sistema non ha confermato la modalità richiesta.");

            var detail = mode == "arch"
                ? "Arch pronto: VNC 192.168.1.50:5900, shell Arch Telnet 192.168.1.50:2323"
                : "Buildroot pronto: VNC 192.168.1.50:5900, Telnet 192.168.1.50:23";
            SetStatus(detail);
            MessageBox.Show(detail, "Avvio completato", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            AppendLog("\r\nERRORE: " + ex.Message + "\r\n");
            SetStatus("Avvio non completato: " + ex.Message);
            MessageBox.Show(ex.Message, "Avvio non completato", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            _serial?.Dispose();
            _serial = null;
            SetBusy(false);
        }
    }

    private async Task<string> WaitForUbootPromptAsync(TimeSpan timeout)
    {
        var buffer = new StringBuilder();
        var stopwatch = Stopwatch.StartNew();
        while (stopwatch.Elapsed < timeout)
        {
            var text = ReadSerial();
            if (text.Length > 0)
            {
                AppendLog(text);
                buffer.Append(text);
                if (text.Contains("U-Boot 2011.12.12") || text.Contains("Hit any key to stop autoboot"))
                {
                    WriteSerial(" ");
                    await Task.Delay(50);
                    WriteSerial(" ");
                }
                if (Regex.IsMatch(buffer.ToString(), @"mt5882\s*#\s*$")) return buffer.ToString();
                if (buffer.Length > 131072) buffer.Remove(0, buffer.Length - 65536);
            }
            await Task.Delay(10);
        }
        throw new TimeoutException("Tempo scaduto in attesa di U-Boot.");
    }

    private async Task<string> RunUbootAsync(string command, TimeSpan timeout)
    {
        AppendLog($"\r\n[PC] → {command}\r\n");
        WriteSerial(command + "\r");
        return await ReadUntilAsync(text => Regex.IsMatch(text, @"mt5882\s*#\s*$"), timeout);
    }

    private async Task<string> ReadUntilAsync(Func<string, bool> completed, TimeSpan timeout)
    {
        var buffer = new StringBuilder();
        var stopwatch = Stopwatch.StartNew();
        while (stopwatch.Elapsed < timeout)
        {
            var text = ReadSerial();
            if (text.Length > 0)
            {
                AppendLog(text);
                buffer.Append(text);
                if (completed(buffer.ToString())) return buffer.ToString();
                if (buffer.Length > 262144) buffer.Remove(0, buffer.Length - 131072);
            }
            await Task.Delay(15);
        }
        throw new TimeoutException("Tempo scaduto durante il comando o l'avvio.");
    }

    private string ReadSerial() => _serial?.IsOpen == true ? _serial.ReadExisting() : string.Empty;
    private void WriteSerial(string text) => _serial?.Write(text);

    private void AppendLog(string text)
    {
        if (InvokeRequired) { BeginInvoke(() => AppendLog(text)); return; }
        _log.AppendText(text);
    }

    private void SetStatus(string text)
    {
        if (InvokeRequired) { BeginInvoke(() => SetStatus(text)); return; }
        _status.Text = text;
    }

    private void SetBusy(bool busy)
    {
        _buildroot.Enabled = !busy;
        _arch.Enabled = !busy;
        _refresh.Enabled = !busy;
        _ports.Enabled = !busy;
        _usbVendor.Enabled = !busy;
    }

    private string ModeName(string mode) => mode == "arch"
        ? (_usbVendor.Checked ? "Arch Linux ARM su USB con driver" : "Arch Linux ARM sperimentale")
        : (_usbVendor.Checked ? "Buildroot USB con driver" : "Buildroot su p27");
    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }
}
