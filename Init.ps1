# Utilizing David Segura's functions
iex (irm sandbox.osdcloud.com)

# David stores the state of the computer in $WindowsPhase, i.e.  the computer is 
# booted to WinPe, at OOBE, or within Windows, etc.

# David has several useful functions built into sandbox.osdcloud.com, which
# is called from functions.osdcloud.com.  We will utilize some of these.
# https://www.osdcloud.com/sandbox/functions
#    AddCapability
#    NetFX
#    RemoveAppx
#    Rsat
#    UpdateDrivers
#    UpdateWindows

Switch ($WindowsPhase) {
    "WinPE" {
        Start-OSDCloud -OSName 'Windows 10 21H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSLicense Volume -Restart
    }

    "OOBE" {
        AddCapability
        RemoveAppx
        UpdateDrivers
        UpdateWindows
        Write-Host -ForegroundColor "Congratz! All done!"
    }

    "Windows" {
        Write-Host -ForegroundColor Cyan "No functions were automatically called."
        Write-Host -ForegroundColor Gray @'
#        AddCapability
#        NetFX
#        RemoveAppx
#        Rsat
#        UpdateDrivers
#        UpdateWindows
'@

    }
}
