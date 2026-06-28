; ============================================================
;  Grafana Hardware Dashboard — Inno Setup Installer Script
;  Produces a professional Windows .exe wizard installer
;  Compile with: Inno Setup 6+ (https://jrsoftware.org/isinfo.php)
; ============================================================

#define MyAppName "Grafana Hardware Dashboard"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Grafana Dashboard Project"
#define MyAppURL "https://github.com/YOUR_USERNAME/grafana-dashboard"
#define MyAppExeName "start-silent.vbs"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\GrafanaDashboard
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=..\LICENSE
OutputDir=.\Output
OutputBaseFilename=GrafanaDashboard-Setup-{#MyAppVersion}

Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardResizable=yes
; Require Windows 10 or later
MinVersion=10.0
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Start dashboard automatically when Windows starts"; GroupDescription: "Startup:"; Flags: checkedonce

[Files]
; Copy all repo files into the install directory
Source: "..\config\*"; DestDir: "{app}\config"; Flags: recursesubdirs ignoreversion
Source: "..\install.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\start-silent.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\uninstall.bat"; DestDir: "{app}"; Flags: ignoreversion
; Assets


[Icons]
Name: "{group}\Start Dashboard"; Filename: "{app}\start-silent.vbs"
Name: "{group}\Stop Dashboard"; Filename: "{app}\stop.bat"
Name: "{group}\Open Dashboard in Browser"; Filename: "http://localhost:3000"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\Grafana Dashboard"; Filename: "{app}\start-silent.vbs"; Tasks: desktopicon

[Run]
; Run the PowerShell installer after files are copied
Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -File ""{app}\install.ps1"""; \
    WorkingDir: "{app}"; \
    StatusMsg: "Downloading Grafana, Prometheus, and exporters... (this may take a few minutes)"; \
    Flags: waituntilterminated runhidden

; Start the dashboard silently right after installation
Filename: "wscript.exe"; \
    Parameters: """{app}\start-silent.vbs"""; \
    Flags: runhidden

; Optionally open the dashboard when done
Filename: "http://localhost:3000"; \
    Description: "Open Dashboard in Browser"; \
    Flags: postinstall shellexec skipifsilent unchecked

[UninstallRun]
Filename: "{app}\uninstall.bat"; Flags: waituntilterminated runhidden

[Registry]
; Startup entry (only if user selected the startup task)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
    ValueType: string; ValueName: "GrafanaDashboard"; \
    ValueData: "wscript.exe ""{app}\start-silent.vbs"""; \
    Flags: uninsdeletevalue; Tasks: startupicon

[Code]
// Pascal scripting: Show a message if the install.ps1 download step fails
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    MsgBox('Installation complete!' + #13#10 +
           'Your hardware dashboard will start automatically with Windows.' + #13#10 +
           'Access it at: http://localhost:3000', mbInformation, MB_OK);
  end;
end;
