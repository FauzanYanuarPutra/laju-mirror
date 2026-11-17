use serde::Serialize;
use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    process::{Child, Command, Output, Stdio},
    sync::Mutex,
    thread,
    time::Duration,
};
use tauri::{AppHandle, Manager, State};

#[derive(Default)]
struct ProcessRegistry(Mutex<HashMap<String, Child>>);

impl Drop for ProcessRegistry {
    fn drop(&mut self) {
        if let Ok(children) = self.0.get_mut() {
            for child in children.values_mut() {
                let _ = child.kill();
                let _ = child.wait();
            }
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DeviceInfo {
    serial: String,
    state: String,
    model: Option<String>,
    product: Option<String>,
    transport: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ToolsStatus {
    adb_available: bool,
    scrcpy_available: bool,
    adb_version: Option<String>,
    scrcpy_version: Option<String>,
    bundled: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CommandResult {
    success: bool,
    message: String,
}

fn hidden_command(program: &Path) -> Command {
    let mut command = Command::new(program);
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x08000000);
    }
    command
}

fn resolve_tool(app: &AppHandle, tool: &str) -> PathBuf {
    let filename = if cfg!(windows) {
        format!("{tool}.exe")
    } else {
        tool.to_string()
    };

    let env_key = if tool == "scrcpy" {
        "LAJUMIRROR_SCRCPY"
    } else {
        "LAJUMIRROR_ADB"
    };
    if let Ok(custom_path) = std::env::var(env_key) {
        let custom_path = PathBuf::from(custom_path);
        if custom_path.is_file() {
            return custom_path;
        }
    }

    if let Ok(resource_dir) = app.path().resource_dir() {
        let bundled = resource_dir.join("tools").join("scrcpy").join(&filename);
        if bundled.is_file() {
            return bundled;
        }
    }

    let development = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("resources")
        .join("tools")
        .join("scrcpy")
        .join(&filename);
    if development.is_file() {
        return development;
    }

    // Command::new also searches PATH for a bare executable name.
    PathBuf::from(filename)
}

fn run_output(program: &Path, args: &[&str]) -> Result<Output, String> {
    hidden_command(program)
        .args(args)
        .stdin(Stdio::null())
        .output()
        .map_err(|error| format!("Could not start {}: {error}", program.display()))
}

fn output_text(output: &Output) -> String {
    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if output.status.success() {
        if stdout.is_empty() { stderr } else { stdout }
    } else if stderr.is_empty() {
        if stdout.is_empty() {
            format!("Process exited with status {}", output.status)
        } else {
            stdout
        }
    } else if stdout.is_empty() {
        stderr
    } else {
        format!("{stderr}\n{stdout}")
    }
}

fn run_adb(app: &AppHandle, args: &[&str]) -> Result<Output, String> {
    let adb = resolve_tool(app, "adb");
    run_output(&adb, args)
}

fn command_result(result: Result<Output, String>) -> CommandResult {
    match result {
        Ok(output) => CommandResult {
            success: output.status.success(),
            message: output_text(&output),
        },
        Err(message) => CommandResult { success: false, message },
    }
}

fn validate_serial(serial: &str) -> Result<(), String> {
    if serial.trim().is_empty() || serial.chars().any(char::is_whitespace) {
        return Err("Invalid device serial.".to_string());
    }
    Ok(())
}

fn validate_host_port(address: &str) -> Result<(), String> {
    let (host, port_text) = address
        .trim()
        .rsplit_once(':')
        .ok_or_else(|| "Enter an address in host:port format.".to_string())?;

    let host = host.trim();
    let host_is_safe = !host.is_empty()
        && host.len() <= 253
        && host
            .chars()
            .all(|character| character.is_ascii_alphanumeric() || ".-:[]_%".contains(character));
    if !host_is_safe {
        return Err("The host contains unsupported characters.".to_string());
    }

    let port: u16 = port_text
        .parse()
        .map_err(|_| "Enter a valid port between 1 and 65535.".to_string())?;
    if port == 0 {
        return Err("Port 0 is not valid.".to_string());
    }
    Ok(())
}

fn validate_port(port: u16) -> Result<(), String> {
    if port == 0 {
        Err("Port must be between 1 and 65535.".to_string())
    } else {
        Ok(())
    }
}

fn version_for(app: &AppHandle, tool: &str) -> Option<String> {
    let path = resolve_tool(app, tool);
    let output = run_output(&path, &["--version"]).ok()?;
    if !output.status.success() {
        return None;
    }
    let text = output_text(&output);
    text.lines().next().map(|line| line.trim().to_string())
}

#[tauri::command]
fn check_tools(app: AppHandle) -> ToolsStatus {
    let adb_version = version_for(&app, "adb");
    let scrcpy_version = version_for(&app, "scrcpy");
    let resource_dir = app.path().resource_dir().ok();
    let bundled = resource_dir
        .map(|path| path.join("tools").join("scrcpy").join(if cfg!(windows) { "scrcpy.exe" } else { "scrcpy" }).is_file())
        .unwrap_or(false);

    ToolsStatus {
        adb_available: adb_version.is_some(),
        scrcpy_available: scrcpy_version.is_some(),
        adb_version,
        scrcpy_version,
        bundled,
    }
}

#[tauri::command]
fn get_devices(app: AppHandle) -> Result<Vec<DeviceInfo>, String> {
    let output = match run_adb(&app, &["devices", "-l"]) {
        Ok(output) => output,
        Err(_) => return Ok(Vec::new()),
    };
    if !output.status.success() {
        return Ok(Vec::new());
    }

    let response = String::from_utf8_lossy(&output.stdout);
    let mut devices = Vec::new();

    for line in response.lines().skip(1) {
        let mut parts = line.split_whitespace();
        let Some(serial) = parts.next() else { continue };
        let Some(state) = parts.next() else { continue };
        if serial.is_empty() || serial == "*" {
            continue;
        }

        let details: Vec<&str> = parts.collect();
        let get_detail = |prefix: &str| -> Option<String> {
            details
                .iter()
                .find_map(|item| item.strip_prefix(prefix))
                .map(|value| value.replace('_', " "))
        };

        let transport = if serial.starts_with("emulator-") {
            "emulator"
        } else if serial.contains(':') {
            "wifi"
        } else {
            "usb"
        };

        devices.push(DeviceInfo {
            serial: serial.to_string(),
            state: state.to_string(),
            model: get_detail("model:"),
            product: get_detail("product:"),
            transport: transport.to_string(),
        });
    }

    devices.sort_by(|left, right| {
        let left_ready = left.state == "device";
        let right_ready = right.state == "device";
        right_ready.cmp(&left_ready).then_with(|| left.serial.cmp(&right.serial))
    });
    Ok(devices)
}

#[tauri::command]
fn start_mirror(
    app: AppHandle,
    state: State<'_, ProcessRegistry>,
    serial: String,
    max_size: u16,
    max_fps: u8,
    bitrate: String,
    fullscreen: bool,
) -> Result<String, String> {
    validate_serial(&serial)?;
    if ![0, 720, 1080, 1440].contains(&max_size) {
        return Err("Choose a supported resolution preset.".to_string());
    }
    if ![30, 60].contains(&max_fps) {
        return Err("Choose 30 or 60 FPS.".to_string());
    }
    if !["4M", "8M", "12M", "20M"].contains(&bitrate.as_str()) {
        return Err("Choose a supported video bitrate preset.".to_string());
    }

    let adb = resolve_tool(&app, "adb");
    let device_check = run_output(&adb, &["-s", &serial, "get-state"])?;
    if !device_check.status.success()
        || String::from_utf8_lossy(&device_check.stdout).trim() != "device"
    {
        return Err("The selected Android device is not authorized or online. Check the phone screen and approve the USB debugging prompt.".to_string());
    }

    let scrcpy = resolve_tool(&app, "scrcpy");
    let mut args = vec![
        "--serial".to_string(),
        serial.clone(),
        "--no-audio".to_string(),
        "--max-fps".to_string(),
        max_fps.to_string(),
        "--video-bit-rate".to_string(),
        bitrate,
        "--window-title".to_string(),
        format!("LajuMirror | {serial}"),
        "--stay-awake".to_string(),
    ];
    if max_size > 0 {
        args.push("--max-size".to_string());
        args.push(max_size.to_string());
    }
    if fullscreen {
        args.push("--fullscreen".to_string());
    }

    let mut registry = state
        .0
        .lock()
        .map_err(|_| "The mirroring process registry is unavailable.".to_string())?;

    // The current desktop UI manages one mirroring window at a time.
    // Remove stale child handles before checking for another active session.
    registry.retain(|_, child| matches!(child.try_wait(), Ok(None)));
    if let Some((active_serial, _)) = registry.iter().find(|(active_serial, _)| *active_serial != &serial) {
        return Err(format!(
            "Mirroring is already active for {active_serial}. Stop that session before starting another device."
        ));
    }

    let existing_status = registry
        .get_mut(&serial)
        .map(|existing| existing.try_wait());

    match existing_status {
        Some(Ok(None)) => {
            return Err("Mirroring is already running for this device.".to_string());
        }
        Some(Ok(Some(_))) | Some(Err(_)) => {
            registry.remove(&serial);
        }
        None => {}
    }

    let child = hidden_command(&scrcpy)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|error| {
            format!(
                "Could not start scrcpy: {error}. Check that scrcpy is installed or included with this build."
            )
        })?;

    registry.insert(serial.clone(), child);
    Ok(format!("Mirroring started for {serial}. Audio forwarding is disabled."))
}

#[tauri::command]
fn stop_mirror(state: State<'_, ProcessRegistry>, serial: String) -> Result<String, String> {
    validate_serial(&serial)?;
    let mut registry = state
        .0
        .lock()
        .map_err(|_| "The mirroring process registry is unavailable.".to_string())?;
    let Some(mut child) = registry.remove(&serial) else {
        return Err("No LajuMirror session is recorded for this device.".to_string());
    };

    let _ = child.kill();
    let _ = child.wait();
    Ok(format!("Mirroring stopped for {serial}."))
}

#[tauri::command]
fn get_running_sessions(state: State<'_, ProcessRegistry>) -> Result<Vec<String>, String> {
    let mut registry = state
        .0
        .lock()
        .map_err(|_| "The mirroring process registry is unavailable.".to_string())?;

    let finished: Vec<String> = registry
        .iter_mut()
        .filter_map(|(serial, child)| match child.try_wait() {
            Ok(None) => None,
            Ok(Some(_)) | Err(_) => Some(serial.clone()),
        })
        .collect();

    for serial in finished {
        registry.remove(&serial);
    }

    Ok(registry.keys().cloned().collect())
}

#[tauri::command]
fn pair_device(app: AppHandle, pairing_address: String, pairing_code: String) -> CommandResult {
    if let Err(message) = validate_host_port(&pairing_address) {
        return CommandResult { success: false, message };
    }
    let code = pairing_code.trim();
    if !(4..=8).contains(&code.len()) || !code.chars().all(|character| character.is_ascii_digit()) {
        return CommandResult {
            success: false,
            message: "Enter the numeric pairing code shown by Android.".to_string(),
        };
    }

    command_result(run_adb(
        &app,
        &["pair", pairing_address.trim(), code],
    ))
}

#[tauri::command]
fn connect_wifi_device(app: AppHandle, address: String) -> CommandResult {
    if let Err(message) = validate_host_port(&address) {
        return CommandResult { success: false, message };
    }
    command_result(run_adb(&app, &["connect", address.trim()]))
}

#[tauri::command]
fn enable_tcpip(app: AppHandle, serial: String, port: u16) -> CommandResult {
    if let Err(message) = validate_serial(&serial).and_then(|_| validate_port(port)) {
        return CommandResult { success: false, message };
    }

    let port_text = port.to_string();
    let result = run_adb(&app, &["-s", &serial, "tcpip", &port_text]);
    if let Ok(output) = &result {
        if output.status.success() {
            thread::sleep(Duration::from_millis(900));
        }
    }
    command_result(result)
}

#[tauri::command]
fn disconnect_device(app: AppHandle, serial: String) -> CommandResult {
    if let Err(message) = validate_serial(&serial) {
        return CommandResult { success: false, message };
    }
    command_result(run_adb(&app, &["disconnect", &serial]))
}

pub fn run() {
    tauri::Builder::default()
        .manage(ProcessRegistry::default())
        .invoke_handler(tauri::generate_handler![
            check_tools,
            get_devices,
            get_running_sessions,
            start_mirror,
            stop_mirror,
            pair_device,
            connect_wifi_device,
            enable_tcpip,
            disconnect_device
        ])
        .run(tauri::generate_context!())
        .expect("error while running LajuMirror");
}
