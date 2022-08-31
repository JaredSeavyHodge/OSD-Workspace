# Call this script with 
#   iex (irm https://tinyurl.com/HCCDeploy)

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
                Start-Process msiexec.exe -ArgumentList $app.Parameters -Wait
            }
            "exe" {
                Start-Process $FileName -ArgumentList $app.Parameters -Wait
            }
        }
    }
}

function ChoiceMenu {
    param(
        [String]$Title,
        [String]$Message,
        [String[]]$Options,
        [Int]$Default=0
    )
    $Answers = @()
    foreach ($Answer in $Options) {
        $Answers += New-Object System.Management.Automation.Host.ChoiceDescription "&$Answer", $Answer

    }


    # $Academic = New-Object System.Management.Automation.Host.ChoiceDescription '&Academic', 'Academic.hccfl.edu'
    # $Family = New-Object System.Management.Automation.Host.ChoiceDescription '&Family', 'Family.hccfl.edu'
    # $None = New-Object System.Management.Automation.Host.ChoiceDescription '&None', 'Do not join.'
    switch ($Answers.count) {
        0 { Write-Error "You must enter an answer option." }
        1 { Write-Error "You must enter more than 1 answer option."}
        2 { $OptionObj = [System.Management.Automation.Host.ChoiceDescription[]]($Answers[0], $Answers[1]) }
        3 { $OptionObj = [System.Management.Automation.Host.ChoiceDescription[]]($Answers[0], $Answers[1], $Answers[2]) }
        4 { $OptionObj = [System.Management.Automation.Host.ChoiceDescription[]]($Answers[0], $Answers[1], $Answers[2], $Answers[3]) }
        5 { Write-Error "Only 4 options are allowed."}
        Default {5}
    }
    # $OptionObj = [System.Management.Automation.Host.ChoiceDescription[]]($Academic, $Family, $None)

    # $title = 'Domain'
    # $message = 'Which domain would you join?'
    $result = $host.ui.PromptForChoice($title, $message, $OptionObj, $Default)
    $result
}

function TryDomainJoin {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $Domain,
        $ComputerName
    )
    $Credential = Get-Credential -Message "Enter your domain credentials to join. ( $domain\<username> )"
    try {
        Rename-Computer $ComputerName
        Write-Host -ForegroundColor White -BackgroundColor DarkMagenta "Joining $Domain"
        Add-Computer -Domain $Domain -NewName $ComputerName -Credential $Credential -Restart -Force
    }
    catch {
        Write-Error $_.Exception.Message
    }
    
}

Switch ($WindowsPhase) {
    "WinPE" {
        Start-OSDCloud -OSName 'Windows 10 21H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSLicense Volume -Restart
    }

    "OOBE" {

        AddCapability -Name "Print.Management*"
        RemoveAppx people,xbox,phone,GamingApp
        NetFX
        UpdateDrivers
        UpdateWindows

        $ComputerName = Read-Host "Computer Name:"
        $Options = "Azure AD", "Family.hccfl.edu", "Academic.hccfl.edu", "None"
        $Result = ChoiceMenu -Title "Domain to Join:" -Message "Azure AD should be chosen most of the time." -Options $Options -Default 3

        switch ($Result) {
            0 {
                Install-Module AADInternals
                Get-AADIntAccessTokenForAADJoin -BPRT $BPRT -SaveToCache
                Join-AADIntDeviceToAzureAD -DeviceName $ComputerName
            }
            1 {
                Write-Output "Preparing the computer for on-prem AD join."
                Write-Output "Installing Software"
                InstallSoftware
                TryDomainJoin -ComputerName $ComputerName -Domain "family.hccfl.edu"
            }
            2 {
                Write-Output "Preparing the computer for on-prem AD join."
                Write-Output "Installing Software"
                InstallSoftware
                TryDomainJoin -ComputerName $ComputerName -Domain "academic.hccfl.edu"
            }
            3 {
                Write-Warning "Not joining a domain.  Renaming the computer and rebooting."
                Rename-Computer $ComputerName -Force -Restart
            }
        }
    }

    "Windows" { 
#        AddCapability
#        NetFX
#        RemoveAppx
#        Rsat
#        UpdateDrivers
#        UpdateWindows

    }
}
