import { useCallback, useEffect, useMemo, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import {
  Activity, Check, ChevronDown, CircleHelp, Cable, CircleDot, Languages,
  LoaderCircle, Monitor, MonitorPlay, RefreshCw, Settings2, ShieldCheck,
  Smartphone, Volume2, Wifi, WifiOff, X, Zap,
} from "lucide-react";

type Device = {
  serial: string;
  state: string;
  model: string | null;
  product: string | null;
  transport: "usb" | "wifi" | "emulator";
};
type ToolsStatus = {
  adbAvailable: boolean;
  scrcpyAvailable: boolean;
  adbVersion: string | null;
  scrcpyVersion: string | null;
  bundled: boolean;
};
type CommandResult = { success: boolean; message: string };
type Language = "id" | "en";

const copy = {
  id: {
    eyebrow: "ANDROID SCREEN COMPANION",
    headline: "Layar lebih luas.\nSuara tetap di HP.",
    intro: "Tampilkan dan kendalikan Android dari Windows lewat USB atau Wi-Fi.",
    devices: "Perangkat",
    refresh: "Segarkan",
    noDevice: "Belum ada perangkat terhubung",
    noDeviceHint: "Sambungkan HP dengan kabel data, aktifkan USB debugging, lalu izinkan komputer di layar HP.",
    connectUsb: "Hubungkan lewat USB",
    usbTab: "USB",
    wifiTab: "Wi-Fi",
    setup: "Pengaturan mirroring",
    quality: "Resolusi maksimum",
    fps: "Frame rate",
    bitrate: "Kualitas video",
    audio: "Audio HP",
    audioValue: "Tetap di HP",
    audioHint: "Audio tidak diteruskan ke laptop",
    launch: "Mulai mirroring",
    stop: "Hentikan mirroring",
    running: "Mirroring sedang berjalan",
    idle: "Siap digunakan",
    toolsMissing: "Komponen belum ditemukan",
    toolsHint: "ADB dan scrcpy harus tersedia. Installer resmi akan menyertakannya.",
    checkTools: "Periksa komponen",
    wirelessTitle: "Koneksi Wi-Fi",
    wirelessHint: "Untuk Android 11 ke atas, gunakan Wireless Debugging. Pastikan HP dan laptop berada di jaringan lokal yang sama.",
    pairAddress: "Alamat pairing, contoh 192.168.1.8:37123",
    pairCode: "Kode pairing",
    pair: "Pair perangkat",
    connectAddress: "Alamat koneksi, contoh 192.168.1.8:42561",
    connect: "Hubungkan",
    tcpTitle: "Alternatif: ADB TCP/IP",
    tcpHint: "Sambungkan USB terlebih dahulu. Cara ini memakai port debugging pada jaringan lokal.",
    phoneIp: "IP HP, contoh 192.168.1.8",
    port: "Port",
    enableConnect: "Aktifkan dan hubungkan",
    disconnect: "Putuskan Wi-Fi",
    help: "Panduan",
    helpLink: "Buka dokumentasi",
    secure: "Koneksi lokal",
    secureHint: "Tidak memakai akun atau cloud relay",
    selected: "Terpilih",
    modelUnknown: "Android",
    authorized: "Siap",
    unauthorized: "Menunggu izin di HP",
    offline: "Offline",
    connecting: "Menghubungkan…",
    chooseDevice: "Pilih perangkat terlebih dahulu.",
    operationFailed: "Operasi gagal",
    sizeUnlimited: "Asli",
  },
  en: {
    eyebrow: "ANDROID SCREEN COMPANION",
    headline: "A wider screen.\nSound stays on your phone.",
    intro: "View and control Android from Windows over USB or Wi-Fi.",
    devices: "Devices",
    refresh: "Refresh",
    noDevice: "No device connected yet",
    noDeviceHint: "Connect a data cable, enable USB debugging, then approve this computer on your phone.",
    connectUsb: "Connect over USB",
    usbTab: "USB",
    wifiTab: "Wi-Fi",
    setup: "Mirroring settings",
    quality: "Maximum size",
    fps: "Frame rate",
    bitrate: "Video quality",
    audio: "Phone audio",
    audioValue: "Stays on phone",
    audioHint: "Audio is not forwarded to the laptop",
    launch: "Start mirroring",
    stop: "Stop mirroring",
    running: "Mirroring is running",
    idle: "Ready",
    toolsMissing: "Required tools not found",
    toolsHint: "ADB and scrcpy are required. The official installer will bundle them.",
    checkTools: "Check tools",
    wirelessTitle: "Wi-Fi connection",
    wirelessHint: "For Android 11+, use Wireless Debugging. Keep your phone and laptop on the same local network.",
    pairAddress: "Pairing address, e.g. 192.168.1.8:37123",
    pairCode: "Pairing code",
    pair: "Pair device",
    connectAddress: "Connection address, e.g. 192.168.1.8:42561",
    connect: "Connect",
    tcpTitle: "Alternative: ADB TCP/IP",
    tcpHint: "Connect USB first. This method uses a debugging port on your local network.",
    phoneIp: "Phone IP, e.g. 192.168.1.8",
    port: "Port",
    enableConnect: "Enable and connect",
    disconnect: "Disconnect Wi-Fi",
    help: "Help",
    helpLink: "Open documentation",
    secure: "Local connection",
    secureHint: "No account or cloud relay required",
    selected: "Selected",
    modelUnknown: "Android",
    authorized: "Ready",
    unauthorized: "Waiting for approval on phone",
    offline: "Offline",
    connecting: "Connecting…",
    chooseDevice: "Select a device first.",
    operationFailed: "Operation failed",
    sizeUnlimited: "Native",
  },
};

function App() {
  const [lang, setLang] = useState<Language>("id");
  const t = copy[lang];
  const [devices, setDevices] = useState<Device[]>([]);
  const [tools, setTools] = useState<ToolsStatus | null>(null);
  const [selectedSerial, setSelectedSerial] = useState("");
  const [activeTab, setActiveTab] = useState<"usb" | "wifi">("usb");
  const [maxSize, setMaxSize] = useState("1080");
  const [fps, setFps] = useState("60");
  const [bitrate, setBitrate] = useState("12M");
  const [pairAddress, setPairAddress] = useState("");
  const [pairCode, setPairCode] = useState("");
  const [connectAddress, setConnectAddress] = useState("");
  const [phoneIp, setPhoneIp] = useState("");
  const [port, setPort] = useState("5555");
  const [runningSerial, setRunningSerial] = useState("");
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ text: string; error?: boolean } | null>(null);

  const selectedDevice = useMemo(
    () => devices.find((device) => device.serial === selectedSerial),
    [devices, selectedSerial],
  );

  const showNotice = (text: string, error = false) => {
    setNotice({ text, error });
    window.setTimeout(() => setNotice(null), 5200);
  };

  const refresh = useCallback(async () => {
    try {
      const [nextDevices, nextTools] = await Promise.all([
        invoke<Device[]>("get_devices"),
        invoke<ToolsStatus>("check_tools"),
      ]);
      setDevices(nextDevices);
      setTools(nextTools);
      setSelectedSerial((current) =>
        nextDevices.some((device) => device.serial === current)
          ? current
          : nextDevices.find((device) => device.state === "device")?.serial ?? nextDevices[0]?.serial ?? "",
      );
    } catch (error) {
      setTools(null);
      showNotice(String(error), true);
    }
  }, []);

  useEffect(() => {
    void refresh();
    const timer = window.setInterval(() => void refresh(), 4000);
    return () => window.clearInterval(timer);
  }, [refresh]);

  const runAction = async (action: () => Promise<CommandResult>) => {
    setBusy(true);
    try {
      const result = await action();
      showNotice(result.message, !result.success);
      await refresh();
      return result.success;
    } catch (error) {
      showNotice(String(error), true);
      return false;
    } finally {
      setBusy(false);
    }
  };

  const startMirroring = async () => {
    if (!selectedSerial) {
      showNotice(t.chooseDevice, true);
      return;
    }
    await runAction(async () => {
      const message = await invoke<string>("start_mirror", {
        serial: selectedSerial,
        maxSize: Number(maxSize),
        maxFps: Number(fps),
        bitrate,
      });
      setRunningSerial(selectedSerial);
      return { success: true, message };
    });
  };

  const stopMirroring = async () => {
    if (!runningSerial) return;
    const serial = runningSerial;
    await runAction(async () => {
      const message = await invoke<string>("stop_mirror", { serial });
      setRunningSerial("");
      return { success: true, message };
    });
  };

  const pairDevice = async () => {
    if (!pairAddress.trim() || !pairCode.trim()) {
      showNotice(lang === "id" ? "Isi alamat pairing dan kode yang tampil di HP." : "Enter the pairing address and code shown on your phone.", true);
      return;
    }
    await runAction(() => invoke<CommandResult>("pair_device", {
      pairingAddress: pairAddress.trim(),
      pairingCode: pairCode.trim(),
    }));
  };

  const connectWifi = async () => {
    if (!connectAddress.trim()) {
      showNotice(lang === "id" ? "Isi alamat koneksi dari halaman Wireless Debugging." : "Enter the connection address from the Wireless Debugging screen.", true);
      return;
    }
    await runAction(() => invoke<CommandResult>("connect_wifi_device", {
      address: connectAddress.trim(),
    }));
  };

  const enableTcpAndConnect = async () => {
    if (!selectedSerial || !phoneIp.trim()) {
      showNotice(lang === "id" ? "Pilih perangkat USB dan isi IP HP." : "Select the USB device and enter its IP address.", true);
      return;
    }
    await runAction(async () => {
      const enabled = await invoke<CommandResult>("enable_tcpip", {
        serial: selectedSerial,
        port: Number(port),
      });
      if (!enabled.success) return enabled;
      return await invoke<CommandResult>("connect_wifi_device", {
        address: phoneIp.trim().includes(":") ? phoneIp.trim() : phoneIp.trim() + ":" + port,
      });
    });
  };

  const disconnectWifi = async () => {
    const wifiDevice = devices.find((device) => device.transport === "wifi" && device.state === "device");
    if (!wifiDevice) {
      showNotice(lang === "id" ? "Tidak ada perangkat Wi-Fi aktif." : "No active Wi-Fi device.", true);
      return;
    }
    await runAction(() => invoke<CommandResult>("disconnect_device", { serial: wifiDevice.serial }));
  };

  const toolsReady = Boolean(tools?.adbAvailable && tools?.scrcpyAvailable);
  const canMirror = Boolean(selectedDevice?.state === "device" && toolsReady);
  const connectedCount = devices.filter((device) => device.state === "device").length;

  return (
    <main className="app-shell">
      <div className="ambient ambient-one" />
      <div className="ambient ambient-two" />
      <header className="topbar">
        <a className="brand" href="#" aria-label="LajuMirror home">
          <span className="brand-mark"><MonitorPlay size={22} strokeWidth={2.2} /></span>
          <span>Laju<span className="brand-light">Mirror</span><small>BY LAJUKAN</small></span>
        </a>
        <div className="top-actions">
          <span className="privacy-pill"><ShieldCheck size={14} /> {t.secure}</span>
          <button className="icon-button" onClick={() => setLang(lang === "id" ? "en" : "id")} title="Change language">
            <Languages size={17} /><span>{lang.toUpperCase()}</span>
          </button>
          <a className="icon-button help-button" href="https://github.com/FauzanYanuarPutra/laju-mirror/tree/main/docs" target="_blank" rel="noreferrer" title={t.helpLink}>
            <CircleHelp size={17} />
          </a>
        </div>
      </header>

      <section className="hero">
        <div className="hero-copy">
          <div className="eyebrow"><span className="pulse-dot" /> {t.eyebrow}</div>
          <h1>{t.headline.split("\n").map((line, index) => <span key={index}>{line}</span>)}</h1>
          <p>{t.intro}</p>
          <div className="hero-points">
            <span><Cable size={15} /> USB</span>
            <span><Wifi size={15} /> Wi-Fi</span>
            <span><Volume2 size={15} /> {t.audioValue}</span>
          </div>
        </div>
        <div className="hero-visual" aria-hidden="true">
          <div className="orbit orbit-a" /><div className="orbit orbit-b" />
          <div className="phone-visual"><div className="phone-camera" /><div className="phone-screen-content"><div className="screen-line line-a" /><div className="screen-line line-b" /><div className="screen-card" /><div className="screen-bars"><i /><i /><i /><i /></div></div><div className="phone-home" /></div>
          <div className="signal-chip"><Zap size={14} fill="currentColor" /> 60 FPS</div>
          <div className="sound-chip"><Volume2 size={15} /><span>PHONE AUDIO</span><Check size={14} /></div>
        </div>
      </section>

      <section className="workspace">
        <div className="panel device-panel">
          <div className="section-heading">
            <div><span className="section-kicker">01 / DEVICE</span><h2>{t.devices}</h2></div>
            <button className="subtle-button" onClick={() => void refresh()} disabled={busy}><RefreshCw size={14} className={busy ? "spin" : ""} /> {t.refresh}</button>
          </div>
          <div className="device-select-wrap">
            {devices.length > 0 ? (
              <div className="device-list">
                {devices.map((device) => (
                  <button key={device.serial} className={"device-row " + (selectedSerial === device.serial ? "selected" : "")} onClick={() => setSelectedSerial(device.serial)}>
                    <span className="device-icon"><Smartphone size={21} /></span>
                    <span className="device-copy"><strong>{device.model || device.product || t.modelUnknown}</strong><small>{device.serial}</small></span>
                    <span className={"connection-tag " + (device.state === "device" ? "online" : "waiting")}>
                      <span />{device.state === "device" ? t.authorized : device.state === "unauthorized" ? t.unauthorized : t.offline}
                    </span>
                    {selectedSerial === device.serial && <Check className="selected-check" size={17} />}
                  </button>
                ))}
              </div>
            ) : (
              <div className="empty-device">
                <div className="empty-icon"><Smartphone size={26} /></div>
                <strong>{t.noDevice}</strong>
                <p>{t.noDeviceHint}</p>
              </div>
            )}
          </div>
          <div className="device-footer">
            <span className="device-count"><CircleDot size={12} /> {connectedCount} {lang === "id" ? "terhubung" : "connected"}</span>
            <span className="tool-state">{toolsReady ? <><span className="tiny-check"><Check size={10} /></span> ADB + scrcpy</> : <><span className="tiny-warning">!</span> {t.toolsMissing}</>}</span>
          </div>
          {tools && !toolsReady && <div className="inline-warning"><Activity size={16} /><span>{t.toolsHint}</span></div>}
        </div>

        <div className="panel control-panel">
          <div className="section-heading">
            <div><span className="section-kicker">02 / CONNECTION</span><h2>{lang === "id" ? "Metode koneksi" : "Connection method"}</h2></div>
            <span className="step-indicator">STEP 02</span>
          </div>
          <div className="tabs" role="tablist">
            <button className={activeTab === "usb" ? "active" : ""} onClick={() => setActiveTab("usb")} role="tab" aria-selected={activeTab === "usb"}><Cable size={16} /> {t.usbTab}</button>
            <button className={activeTab === "wifi" ? "active" : ""} onClick={() => setActiveTab("wifi")} role="tab" aria-selected={activeTab === "wifi"}><Wifi size={16} /> {t.wifiTab}</button>
          </div>

          {activeTab === "usb" ? (
            <div className="connection-content">
              <div className="connection-intro"><span className="round-icon"><Cable size={19} /></span><div><strong>{lang === "id" ? "Koneksi USB langsung" : "Direct USB connection"}</strong><p>{lang === "id" ? "Paling stabil dan direkomendasikan untuk penggunaan pertama." : "Most stable and recommended for your first connection."}</p></div></div>
              <ol className="mini-steps">
                <li><span>1</span>{lang === "id" ? "Aktifkan USB debugging di Opsi pengembang." : "Enable USB debugging in Developer options."}</li>
                <li><span>2</span>{lang === "id" ? "Sambungkan kabel data dan izinkan komputer di HP." : "Connect the data cable and authorize this computer."}</li>
                <li><span>3</span>{lang === "id" ? "Pilih perangkat di daftar sebelah kiri." : "Select your device in the list on the left."}</li>
              </ol>
              <div className="hint-box"><ShieldCheck size={16} /><span>{lang === "id" ? "Gunakan kabel yang mendukung transfer data, bukan kabel khusus pengisian daya." : "Use a data-capable cable, not a charge-only cable."}</span></div>
            </div>
          ) : (
            <div className="connection-content wifi-content">
              <div className="connection-intro"><span className="round-icon wifi-round"><Wifi size={19} /></span><div><strong>{t.wirelessTitle}</strong><p>{t.wirelessHint}</p></div></div>
              <div className="form-block">
                <div className="form-label-row"><label>{lang === "id" ? "ANDROID WIRELESS DEBUGGING" : "ANDROID WIRELESS DEBUGGING"}</label><span className="recommended">{lang === "id" ? "DISARANKAN" : "RECOMMENDED"}</span></div>
                <input value={pairAddress} onChange={(e) => setPairAddress(e.target.value)} placeholder={t.pairAddress} autoComplete="off" />
                <div className="input-row">
                  <input value={pairCode} onChange={(e) => setPairCode(e.target.value)} placeholder={t.pairCode} inputMode="numeric" autoComplete="one-time-code" />
                  <button className="outline-action" onClick={() => void pairDevice()} disabled={busy}>{busy ? <LoaderCircle className="spin" size={15} /> : null}{t.pair}</button>
                </div>
                <input value={connectAddress} onChange={(e) => setConnectAddress(e.target.value)} placeholder={t.connectAddress} autoComplete="off" />
                <button className="wide-outline" onClick={() => void connectWifi()} disabled={busy}>{t.connect}</button>
              </div>
              <div className="divider-label"><span>{lang === "id" ? "ATAU METODE USB KE WI-FI" : "OR USB TO WI-FI METHOD"}</span></div>
              <div className="form-block compact-form">
                <strong>{t.tcpTitle}</strong><p>{t.tcpHint}</p>
                <input value={phoneIp} onChange={(e) => setPhoneIp(e.target.value)} placeholder={t.phoneIp} autoComplete="off" />
                <div className="input-row">
                  <label className="port-field"><span>{t.port}</span><input value={port} onChange={(e) => setPort(e.target.value)} inputMode="numeric" /></label>
                  <button className="outline-action" onClick={() => void enableTcpAndConnect()} disabled={busy}>{t.enableConnect}</button>
                </div>
              </div>
              <button className="disconnect-link" onClick={() => void disconnectWifi()} disabled={busy}><WifiOff size={14} /> {t.disconnect}</button>
            </div>
          )}
        </div>

        <div className="panel settings-panel">
          <div className="section-heading">
            <div><span className="section-kicker">03 / DISPLAY</span><h2>{t.setup}</h2></div>
            <Settings2 size={18} className="heading-icon" />
          </div>
          <div className="settings-grid">
            <label className="setting-field"><span>{t.quality}</span><span className="select-wrap"><select value={maxSize} onChange={(e) => setMaxSize(e.target.value)}><option value="720">720p</option><option value="1080">1080p</option><option value="1440">1440p</option><option value="0">{t.sizeUnlimited}</option></select><ChevronDown size={14} /></span></label>
            <label className="setting-field"><span>{t.fps}</span><span className="select-wrap"><select value={fps} onChange={(e) => setFps(e.target.value)}><option value="30">30 FPS</option><option value="60">60 FPS</option></select><ChevronDown size={14} /></span></label>
            <label className="setting-field full-field"><span>{t.bitrate}</span><span className="select-wrap"><select value={bitrate} onChange={(e) => setBitrate(e.target.value)}><option value="4M">{lang === "id" ? "Hemat · 4 Mbps" : "Data saver · 4 Mbps"}</option><option value="8M">Balanced · 8 Mbps</option><option value="12M">High · 12 Mbps</option><option value="20M">Very high · 20 Mbps</option></select><ChevronDown size={14} /></span></label>
          </div>
          <div className="audio-card">
            <span className="audio-icon"><Volume2 size={17} /></span>
            <span className="audio-copy"><strong>{t.audio}</strong><small>{t.audioHint}</small></span>
            <span className="audio-toggle"><span /></span>
          </div>
          <button className="launch-button" onClick={() => runningSerial ? void stopMirroring() : void startMirroring()} disabled={busy || (!runningSerial && !canMirror)}>
            {busy ? <LoaderCircle size={18} className="spin" /> : runningSerial ? <X size={18} /> : <MonitorPlay size={18} />}
            {runningSerial ? t.stop : t.launch}
            {!busy && !runningSerial && <span className="button-shortcut">↵</span>}
          </button>
          <div className="session-status"><span className={runningSerial ? "status-led active-led" : "status-led"} />{runningSerial ? t.running : t.idle}{runningSerial && <span className="running-device">{runningSerial}</span>}</div>
        </div>
      </section>

      <footer className="footer">
        <div className="footer-brand"><span className="footer-mark"><Monitor size={14} /></span> LAJUMIRROR <span className="footer-separator">·</span> {lang === "id" ? "Dibuat untuk layar yang lebih luas." : "Made for a wider screen."}</div>
        <div className="footer-meta"><span><ShieldCheck size={13} /> {t.secureHint}</span><a href="https://github.com/FauzanYanuarPutra/laju-mirror" target="_blank" rel="noreferrer">GitHub ↗</a></div>
      </footer>

      {notice && <div className={"toast " + (notice.error ? "toast-error" : "")}><span>{notice.error ? <X size={16} /> : <Check size={16} />}</span>{notice.text}<button onClick={() => setNotice(null)} aria-label="Close notification"><X size={14} /></button></div>}
      <div className="sr-only" aria-live="polite">{runningSerial ? t.running : t.idle}</div>
    </main>
  );
}

export default App;