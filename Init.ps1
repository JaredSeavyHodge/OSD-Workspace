# Call this script with 
#   iex (irm https://tinyurl.com/osdcloud)

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

function Get-M365Config {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Destination
    )

    $config = @'
<Configuration ID="d9bd8d5c-adaa-4cf1-a70d-659fa1450f72">
    <Info Description="Standard User Deployment" />
    <Add OfficeClientEdition="64" Channel="MonthlyEnterprise" MigrateArch="TRUE">
      <Product ID="O365ProPlusRetail">
        <Language ID="en-us" />
        <ExcludeApp ID="Groove" />
        <ExcludeApp ID="Lync" />
        <ExcludeApp ID="Bing" />
      </Product>
    </Add>
    <Property Name="SharedComputerLicensing" Value="1" />
    <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
    <Property Name="DeviceBasedLicensing" Value="0" />
    <Property Name="SCLCacheOverride" Value="0" />
    <Property Name="TenantId" Value="6c031f94-c402-433a-92d2-2d3ce8516da3" />
    <Updates Enabled="TRUE" />
    <RemoveMSI>
      <IgnoreProduct ID="InfoPath" />
      <IgnoreProduct ID="InfoPathR" />
      <IgnoreProduct ID="PrjPro" />
      <IgnoreProduct ID="PrjStd" />
      <IgnoreProduct ID="SharePointDesigner" />
      <IgnoreProduct ID="VisPro" />
      <IgnoreProduct ID="VisStd" />
    </RemoveMSI>
    <AppSettings>
      <Setup Name="Company" Value="Hillsborough Community College" />
    </AppSettings>
    <Display Level="Full" AcceptEULA="TRUE" />
  </Configuration>
'@
    $config | out-file "$Destination"
    
}

function InstallSoftware {
    $Destination = $env:temp
    Get-M365Config -destination "$Destination\m365config.xml"
    $Software = @(
        @{
            Name = "Google Chrome"
            URI = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
            Parameters = "/i googlechromestandaloneenterprise64.msi /qn"
        },
        @{
            
            Name = "Microsoft 365 Apps"
            URI = "https://officecdn.microsoft.com/pr/wsus/setup.exe"
            Parameters = "/configure $Destination\m365config.xml"
        }
    )
    foreach ( $app in $Software) {
        $WebClient = New-Object System.Net.WebClient
        $FileName = $app.URI.Substring($app.URI.LastIndexOf('/')+1)
        $WebClient.DownloadFile($app.URI,"$Destination\$FileName")
        
        $Ext = $FileName.Substring($FileName.LastIndexOf('.')+1)
        cd $Destination
        switch ($Ext) {
            "msi" {
                Start-Process msiexec.exe -ArgumentList $app.Parameters
            }
            "exe" {
                Start-Process $FileName -ArgumentList $app.Parameters
            }
        }

        pause
    }
   

}

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
