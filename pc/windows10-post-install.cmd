REM @echo off
echo "Post-install configuration script for Windows 10"
rem tested on 22H2 (19045)
rem "Memory in use" after restart: 1.2GB -> 930MB
rem background+windows processes: 18+81 -> 12+65
rem Disk "Used Space" after enabling compression: 12.2GB

rem REVIEW THE COMMANDS BEFORE EXECUTING OR MAKE BACKUP! THE CHANGES CANNOT BE REVERTED!

setlocal

call:require_administrator
if %errorlevel% neq 0 (
    goto end
)

call:speedup_ntfs
call:disable_hibernation
call:disable_pagefile
call:disable_system_restore
call:disable_updates
call:disable_data_logging
call:block_telemetry_hosts
call:disable_defender
call:disable_obtrusive_services
call:disable_useless_services
call:uninstall_onedrive
call:delete_edge_browser
call:uninstall_default_apps
call:cleanup_explorer_thispc

rem per-user configuration:
call:user_configure_explorer
call:user_improve_ui_performance
call:user_configure_console
rem call:user_set_environment_path "c:\bin;"
rem call:user_set_file_associations

call:perform_dotnet_compilation
call:enable_auto_login
echo.
echo "Done"
pause
exit

:require_administrator
    echo "check if we have administrator rights"
    openfiles >nul
    if %errorlevel% neq 0 (
        echo "Please run the script as administrator"
        exit /b 1
    )
exit /b


:perform_dotnet_compilation
    echo.
    echo "Compiling .NET files;  this will take 100% CPU usage for a while"
    %WINDIR%\Microsoft.NET\Framework64\v4.0.30319\ngen eqi
exit /b

:speedup_ntfs
    echo.
    echo "improve NTFS disk speed"
    fsutil behavior set Disable8dot3 1
    fsutil behavior set DisableLastAccess 1
exit /b


:disable_hibernation
    echo.
    echo "disable hibernation"
    powercfg /hibernate off
exit /b


:disable_pagefile
    echo.
    echo "disable page file"
    wmic computersystem where name="%COMPUTERNAME%" set AutomaticManagedPagefile=False
    wmic pagefileset where name="C:\\pagefile.sys" delete
exit /b


:disable_system_restore
    echo.
    echo "disable system restore"

    echo "delete all restore points"
    vssadmin delete shadows /for=c: /all /quiet
    powershell -command "Disable-ComputerRestore -Drive C:"

    echo "disable system restore task"
    schtasks /change /TN "Microsoft\Windows\SystemRestore\SR" /disable >nul

    echo "disable service: Microsoft Software Shadow Copy Provider"
    sc config swprv  start=disabled

    echo "disable service: Volume Shadow Copy"
    sc config VSS  start=disabled
exit /b


:disable_updates
    echo.
    echo "disable updates entirely"

    echo "disable service: WindowsUpdate"
    sc config wuauserv  start=disabled

    echo "disable service: Update Orchestrator Service"
    sc config UsoSvc  start=disabled

    echo "take ownership for the dir"
    takeown /a /r /f %WINDIR%\System32\Tasks\Microsoft\Windows\UpdateOrchestrator

    echo "grant full access file permissions to administrators"
    icacls %WINDIR%\System32\Tasks\Microsoft\Windows\UpdateOrchestrator /t /grant administrators:f

    echo "disable tasks"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\UpdateOrchestrator\Schedule Scan'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\UpdateOrchestrator\USO_UxBroker'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\UpdateOrchestrator\Schedule Scan Static Task'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\UpdateOrchestrator\Report Policies'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\UpdateOrchestrator\UpdateModelTask'"
exit /b


:disable_data_logging
    echo.
    echo "disable data logging services"
    sc config diagtrack  start=disabled
    sc config dmwappushservice  start=disabled
    sc config RetailDemo  start=disabled
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f >nul
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f >nul
    schtasks /change /TN "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Application Experience\ProgramDataUpdater" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Application Experience\StartupAppTask" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" /disable >nul
    echo "" >C:\ProgramData\Microsoft\Diagnosis\ETLLogs\AutoLogger\AutoLogger-Diagtrack-Listener.etl
exit /b


:block_telemetry_hosts
    findstr telemetry.microsoft.com %WINDIR%\system32\drivers\etc\hosts >nul
    if %errorlevel% neq 0 (
        echo.
        echo "block MS telemetry hosts"
        echo 0.0.0.0 a-0001.a-msedge.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 choice.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 choice.microsoft.com.nsatc.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 compatexchange.cloudapp.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 corp.sts.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 corpext.msitadfs.glbdns2.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 cs1.wpc.v0cdn.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 df.telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 diagnostics.support.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 fe2.update.microsoft.com.akadns.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 feedback.microsoft-hohm.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 feedback.search.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 feedback.windows.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 i1.services.social.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 i1.services.social.microsoft.com.nsatc.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 oca.telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 oca.telemetry.microsoft.com.nsatc.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 pre.footprintpredict.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 redir.metaservices.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 reports.wes.df.telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 services.wes.df.telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 settings-sandbox.data.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 sls.update.microsoft.com.akadns.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 sqm.df.telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 sqm.telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 sqm.telemetry.microsoft.com.nsatc.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 statsfe1.ws.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 statsfe2.update.microsoft.com.akadns.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 statsfe2.ws.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 survey.watson.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 telecommand.telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 telecommand.telemetry.microsoft.com.nsatc.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 telemetry.appex.bing.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 telemetry.urs.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 vortex-sandbox.data.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 vortex-win.data.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 vortex.data.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 watson.live.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 watson.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 watson.ppe.telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 watson.telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 watson.telemetry.microsoft.com.nsatc.net >>%WINDIR%\system32\drivers\etc\hosts
        echo 0.0.0.0 wes.df.telemetry.microsoft.com >>%WINDIR%\system32\drivers\etc\hosts
    )
exit /b


:disable_defender
    echo.
    echo "disable Windows Defender"

    rem echo "Now disable Tamper Protection MANUALLY:"
    rem echo "1. Press Windows key to open Start Menu"
    rem echo "2. Enter "tamper" and press Enter"
    rem echo "3. set Tamper Protection = Off"
    rem pause

    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d "1" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\MpEngine" /v "MpEnablePus" /t REG_DWORD /d "0" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableBehaviorMonitoring" /t REG_DWORD /d "1" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableIOAVProtection" /t REG_DWORD /d "1" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableOnAccessProtection" /t REG_DWORD /d "1" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d "1" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRoutinelyTakingAction" /t REG_DWORD /d "1" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableScanOnRealtimeEnable" /t REG_DWORD /d "1" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\Reporting" /v "DisableEnhancedNotifications" /t REG_DWORD /d "1" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\SpyNet" /v "DisableBlockAtFirstSeen" /t REG_DWORD /d "1" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\SpyNet" /v "SpynetReporting" /t REG_DWORD /d "0" /f >nul
    reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows Defender\SpyNet" /v "SubmitSamplesConsent" /t REG_DWORD /d "2" /f >nul
    reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger" /v "Start" /t REG_DWORD /d "0" /f >nul
    reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger" /v "Start" /t REG_DWORD /d "0" /f >nul

    echo "disable systray icon"
    reg delete "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "SecurityHealth" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run" /v "SecurityHealth" /f >nul

    echo "remove context menu"
    reg delete "HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers\EPP" /f >nul
    reg delete "HKEY_CLASSES_ROOT\Directory\shellex\ContextMenuHandlers\EPP" /f >nul
    reg delete "HKEY_CLASSES_ROOT\Drive\shellex\ContextMenuHandlers\EPP" /f >nul

    echo "disable services"
    reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\mpssvc" /v "Start" /t REG_DWORD /d "4" /f >nul
    reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\SecurityHealthService" /v "Start" /t REG_DWORD /d "4" /f >nul
    reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\WdFilter" /v "Start" /t REG_DWORD /d "4" /f >nul
    reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\WdNisDrv" /v "Start" /t REG_DWORD /d "4" /f >nul
    reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\WdNisSvc" /v "Start" /t REG_DWORD /d "4" /f >nul
    reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\WinDefend" /v "Start" /t REG_DWORD /d "4" /f >nul

    echo "disable tasks"
    schtasks /change /TN "Microsoft\Windows\ExploitGuard\ExploitGuard MDM policy Refresh" /disable
    schtasks /change /TN "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance" /disable
    schtasks /change /TN "Microsoft\Windows\Windows Defender\Windows Defender Cleanup" /disable
    schtasks /change /TN "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan" /disable
    schtasks /change /TN "Microsoft\Windows\Windows Defender\Windows Defender Verification" /disable
exit /b


:disable_obtrusive_services
    echo.
    echo "disable obtrusive scheduled tasks and services"

    schtasks /change /TN "Microsoft\Windows\Autochk\Proxy" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Chkdsk\ProactiveScan" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Defrag\ScheduledDefrag" /disable >nul
    schtasks /change /TN "Microsoft\Windows\DiskCleanup\SilentCleanup" /disable >nul
    schtasks /change /TN "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" /disable >nul

    schtasks /change /TN "Microsoft\Windows\Feedback\Siuf\DmClient" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Maintenance\WinSAT" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Registry\RegIdleBackup" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Time Synchronization\SynchronizeTime" /disable >nul
    schtasks /change /TN "Microsoft\Windows\Time Zone\SynchronizeTimeZone" /disable >nul

    echo "disable Windows Error Reporting Service"
    schtasks /change /TN "Microsoft\Windows\Windows Error Reporting\QueueReporting" /disable >nul
    sc config WerSvc  start=disabled

    echo "disable Background Intelligent Transfer Service"
    sc config BITS  start=disabled

    echo "disable Microsoft Windows SMS Router Service"
    sc config SmsRouter  start=disabled

    echo "disable Microsoft Account Sign-in Assistant"
    sc config wlidsvc  start=disabled

    echo "disable Cryptographic Services"
    sc config CryptSvc  start=disabled

    echo "disable Microsoft Store Install Service"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\InstallService\ScanForUpdates'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\InstallService\ScanForUpdatesAsUser'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\InstallService\SmartRetry'"
    sc config InstallService  start=disabled

    echo "disable Windows Search"
    sc config WSearch  start=disabled

    rem echo "Now MANUALLY add outbound firewall rule to block C:\Windows\ImmersiveControlPanel\SystemSettings.exe"
    rem echo "Now MANUALLY add outbound firewall rule to block C:\Windows\SystemApps\Microsoft.Windows.Search_XXX\searchapp.exe"
    rem pause
exit /b


:disable_useless_services
    echo.
    echo "disable useless tasks and services"

    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\CloudExperienceHost\CreateObjectTask'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\FileHistory\File History (maintenance mode)'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\NetTrace\GatherNetworkInfo'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Bluetooth\UninstallDeviceTask'"
    rem powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Chkdsk\SyspartRepair'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\DiskFootprint\Diagnostics'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\DiskFootprint\StorageSense'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Flighting\OneSettings\RefreshCache'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\LanguageComponentsInstaller\ReconcileLanguageResources'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Location\WindowsActionDialog'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Management\Provisioning\Cellular'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Maps\MapsToastTask'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\PI\Sqm-Tasks'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Plug and Play\Sysprep Generalize Drivers'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Servicing\StartComponentCleanup'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Shell\FamilySafetyMonitor'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Shell\FamilySafetyRefreshTask'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\SpacePort\SpaceAgentTask'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\SpacePort\SpaceManagerTask'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Speech\SpeechModelDownloadTask'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\StateRepository\MaintenanceTasks'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Sysmain\ResPriStaticDbSync'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Sysmain\WsSwapAssessmentTask'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\USB\Usb-Notifications'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\WaaSMedic\PerformRemediation'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\WCM\WiFiTask'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\WOF\WIM-Hash-Management'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Work Folders\Work Folders Logon Synchronization'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Work Folders\Work Folders Maintenance Work'"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\WwanSvc\NotificationTask'"

    rem Set-Service -name ... -StartupType disabled

    echo "disable GameDVR and Broadcast User Service"
    sc config BcastDVRUserService_30bc9  start=disabled

    echo "disable MessagingService_30bc9"
    sc config MessagingService_30bc9  start=disabled

    echo "disable Contact Data_3490e"
    sc config PimIndexMaintenanceSvc_3490e  start=disabled

    echo "disable Connected Devices Platform Service"
    sc config CDPSvc  start=disabled
    sc config CDPUserSvc_3490e  start=disabled

    echo "disable Windows Mobile Hotspot Service"
    sc config icssvc  start=disabled

    echo "disable Diagnostic Policy Service"
    sc config DPS  start=disabled

    echo "disable Geolocation Service"
    sc config lfsvc  start=disabled

    echo "disable Xbox Live Game Save"
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\XblGameSave\XblGameSaveTask'"
    sc config XblGameSave  start=disabled
    sc config XblAuthManager  start=disabled

    echo "disable Optimize drives"
    sc config defragsvc  start=disabled

    echo "disable Windows Media Player Network Sharin..."
    powershell -command "Disable-ScheduledTask -TaskName 'Microsoft\Windows\Windows Media Sharing\UpdateLibrary'"
    sc config WMPNetworkSvc  start=disabled

    echo "disable Payments and NFC/SE Manager"
    sc config SEMgrSvc  start=disabled

    echo "disable Touch Keyboard and Handwriting Panel Service"
    sc config TabletInputService  start=disabled

    echo "disable Downloaded Maps Manager"
    sc config MapsBroker  start=disabled

    echo "disable CNG Key Isolation"
    sc config KeyIso  start=disabled

    echo "disable SSDP Discovery"
    sc config SSDPSRV  start=disabled

    echo "disable Windows Push Notifications System Service"
    sc config WpnService  start=disabled
    sc config WpnUserService_3490e  start=disabled

    echo "disable Windows Backup"
    sc config SDRSVC  start=disabled

    echo "disable Windows Biometric Service"
    sc config WbioSrvc  start=disabled

    echo "disable Windows Time"
    sc config W32Time  start=disabled

    echo "disable remote desktop services"
    rem Remote Access Connection Manager
    sc config RasMan  start=disabled
    sc config SessionEnv  start=disabled
    sc config TermService  start=disabled
    sc config UmRdpService  start=disabled

    echo "disable Print Spooler"
    sc config Spooler  start=disabled

    echo "disable Web Account Manager"
    sc config TokenBroker  start=disabled

    echo "disable Data Usage"
    sc config DusmSvc  start=disabled

    echo "disable Windows License Manager Service"
    sc config LicenseManager  start=disabled

    echo "disable Program Compatibility Assistant"
    sc config PcaSvc start=disabled

    echo "disable Distributed Link Tracking Client"
    sc config TrkWks  start=disabled

    sc config BthAvctpSvc  start=disabled
    sc config IKEEXT  start=disabled
    sc config PolicyAgent  start=disabled
    sc config camsvc start=disabled
exit /b


:uninstall_onedrive
    echo.
    echo "uninstalling OneDrive;  do not interrupt"
    taskkill /f /im OneDrive.exe
    ping 127.0.0.1 -n 3 >nul
    "%SYSTEMROOT%\SysWOW64\OneDriveSetup.exe" /uninstall
    ping 127.0.0.1 -n 6 >nul
    rd /s /q "%USERPROFILE%\OneDrive"
    rd /s /q "%LOCALAPPDATA%\Microsoft\OneDrive"
    rd /s /q "%PROGRAMDATA%\Microsoft OneDrive"
    reg delete "HKEY_CURRENT_USER\Environment" /v "OneDrive" /f >nul

    rem Remove the automatic start item for OneDrive from the default user profile registry hive
    reg load "HKLM\Temp" "C:\Users\Default\NTUSER.DAT" >nul
    reg delete "HKLM\Temp\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f >nul
    reg unload "HKLM\Temp" >nul
exit /b


:delete_edge_browser
    echo.
    echo "delete MS Edge browser"

    rd /s /q "c:\Program Files (x86)\Microsoft\Edge"

    taskkill /f /im MicrosoftEdgeUpdate.exe
    ping 127.0.0.1 -n 3 >nul
    rd /s /q "c:\Program Files (x86)\Microsoft\EdgeUpdate"
exit /b


:uninstall_default_apps
    rem powershell -command "Get-AppxPackage -AllUsers Microsoft.SkypeApp | Remove-AppxPackage -AllUsers"

    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.DesktopAppInstaller'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.GetHelp'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.Getstarted'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.HEIFImageExtension'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.Microsoft3DViewer'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.MicrosoftEdgeStable'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.MicrosoftOfficeHub'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.MicrosoftSolitaireCollection'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.MicrosoftStickyNotes'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.MixedReality.Portal'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.MSPaint'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.Office.OneNote'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.People'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.ScreenSketch'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.SkypeApp'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.StorePurchaseApp'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.Wallet'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.WebMediaExtensions'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.WebpImageExtension'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.Windows.Photos'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.WindowsAlarms'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.WindowsCalculator'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.WindowsCamera'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'microsoft.windowscommunicationsapps'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.WindowsFeedbackHub'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.WindowsMaps'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.WindowsSoundRecorder'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.YourPhone'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.ZuneMusic'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq 'Microsoft.ZuneVideo'} | Remove-AppxProvisionedPackage -Online -AllUsers"
    powershell -command "Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -match 'Microsoft.Xbox'} | ForEach-Object { Remove-AppxProvisionedPackage -Online -AllUsers -Package $_.PackageName }"

    rem Get-WindowsOptionalFeature -Online | Where-Object {$_.State -eq "Enabled"} | Select-Object -ExpandProperty FeatureName
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName Internet-Explorer-Optional-amd64"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName MediaPlayback"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName MicrosoftWindowsPowerShellV2"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName MicrosoftWindowsPowerShellV2Root"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName MSRDC-Infrastructure"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName NetFx4-AdvSrvs"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName Printing-Foundation-Features"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName Printing-Foundation-InternetPrinting-Client"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName Printing-PrintToPDFServices-Features"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName Printing-XPSServices-Features"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName SearchEngine-Client-Package"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName SmbDirect"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName WCF-Services45"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName WCF-TCP-PortSharing45"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName Windows-Defender-Default-Definitions"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName WindowsMediaPlayer"
    powershell -command "Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName WorkFolders-Client"

    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-OneCore-DirectX-Database-FOD*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-Windows-LanguageFeatures-Handwriting-en-us*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-Windows-LanguageFeatures-OCR-en-us*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-Windows-LanguageFeatures-Speech-en-us*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-Windows-UserExperience-Desktop*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'OpenSSH-Client*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-OneCore-ApplicationModel-Sync-Desktop-FOD*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-Windows-Hello-Face*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-Windows-InternetExplorer-Optional*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-Windows-MediaPlayer*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-Windows-QuickAssist*' | Remove-WindowsPackage -Online -NoRestart"
    powershell -command "Get-WindowsPackage -Online -PackageName 'Microsoft-Windows-TabletPCMath*' | Remove-WindowsPackage -Online -NoRestart"
exit /b


:cleanup_explorer_thispc
    echo.
    echo "remove all Folders from Explorer's This PC view"

    rem save the original state to be able to revert the changes
    reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace" MyComputer-Folders.backup.reg

    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" /f >nul
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" /f >nul
exit /b


:user_configure_explorer
    echo.
    echo "configure Explorer view"
    reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "LaunchTo" /t REG_DWORD /d 1 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /t REG_DWORD /d 1 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 0 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "IconsOnly" /t REG_DWORD /d 1 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "SharingWizardOn" /t REG_DWORD /d 0 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowSuperHidden" /t REG_DWORD /d 1 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowCompColor" /t REG_DWORD /d 1 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowInfoTip" /t REG_DWORD /d 1 /f >nul
exit /b


:user_improve_ui_performance
    echo.
    echo "configure UI for max performance"
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListviewShadow" /t REG_DWORD /d 0 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ListviewAlphaSelect" /t REG_DWORD /d 0 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /t REG_DWORD /d 0 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFXSetting" /t REG_DWORD /d 3 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM" /v "EnableAeroPeek" /t REG_DWORD /d 0 /f >nul
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM" /v "AlwaysHibernateThumbnails" /t REG_DWORD /d 0 /f >nul
    reg add "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /v "MinAnimate" /t REG_DWORD /d 0 /f >nul
    reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "UserPreferencesMask" /t REG_BINARY /d "9012028090000000" /f >nul
    rem reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "UserPreferencesMask" /t REG_BINARY /d "9032078010000000" /f >nul
    reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 0 /f
    reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f

    reg add "HKEY_CURRENT_USER\Control Panel\International\User Profile" /v HttpAcceptLanguageOptOut /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\InputPersonalization\TrainedDataStore" /v HarvestContacts /t REG_DWORD /d 0 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Personalization\Settings" /v AcceptedPrivacyPolicy /t REG_DWORD /d 0 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" /v Disabled /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" /v DisabledByUser /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.PPIProjection_cw5n1h2txyewy" /v Disabled /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.PPIProjection_cw5n1h2txyewy" /v DisabledByUser /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.SkypeApp_kzf8qxf38zg5c" /v Disabled /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.SkypeApp_kzf8qxf38zg5c" /v DisabledByUser /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.Windows.Photos_8wekyb3d8bbwe" /v Disabled /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.Windows.Photos_8wekyb3d8bbwe" /v DisabledByUser /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.YourPhone_8wekyb3d8bbwe" /v Disabled /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\Microsoft.YourPhone_8wekyb3d8bbwe" /v DisabledByUser /t REG_DWORD /d 1 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShellState /t REG_BINARY /d 240000003C2800000000000000000000 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 01 /t REG_DWORD /d 0 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f
exit /b


:user_configure_console
    echo.
    echo "configure Console window"
    reg add "HKEY_CURRENT_USER\Console" /v "ColorTable00" /t REG_DWORD /d 0x232629 /f >nul
    reg add "HKEY_CURRENT_USER\Console" /v "ColorTable15" /t REG_DWORD /d 0xffffff /f >nul
    reg add "HKEY_CURRENT_USER\Console" /v "ScreenColors" /t REG_DWORD /d 0xf /f >nul
    reg add "HKEY_CURRENT_USER\Console" /v "TerminalScrolling" /t REG_DWORD /d 1 /f >nul
    reg add "HKEY_CURRENT_USER\Console" /v "QuickEdit" /t REG_DWORD /d 1 /f >nul
    reg add "HKEY_CURRENT_USER\Console" /v "FaceName" /t REG_SZ /d "Consolas" /f >nul
exit /b


:user_set_environment_path
    set value=%~1
    echo.
    echo "set user path"
    reg add "HKEY_CURRENT_USER\Environment" /v "Path" /t REG_SZ /d %value% /f >nul
exit /b


:user_set_file_associations
    echo.
    echo "set file associations"
    for %%i in (txt md conf) do (
        assoc .%%i=%%ifile
        ftype %%ifile="c:\bin\notepad++\notepad++.exe" "%%1"
    )

    for %%i in (jpg jpeg png bmp) do (
        assoc .%%i=%%ifile
        ftype %%ifile="c:\bin\iview\i_view64.exe" "%%1"
    )

    for %%i in (mp4 mkv webm avi ts) do (
        assoc .%%i=%%ifile
        ftype %%ifile="c:\bin\mpv\mpv.exe" "%%1"
    )

    for %%i in (mp3 m4a ogg opus mpc flac wv ape wav) do (
        assoc .%%i=%%ifile
        ftype %%ifile="c:\bin\phiola-2\phiola-gui.exe" "%%1"
    )
exit /b


:enable_auto_login
    echo.
    echo "enable auto login without password prompt"
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v "DevicePasswordLessBuildVersion" /t REG_DWORD /d 0 /f >nul
    echo "In this window uncheck `Users Must Enter A User Name And Password To Use This Computer`"
    netplwiz
exit /b
