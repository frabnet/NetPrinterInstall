Write-Host "NetPrinterInstall v2.0" -ForegroundColor Green 
Write-Host "https://github.com/frabnet/NetPrinterInstall" -ForegroundColor Green
Write-Host "---"
Write-Host ""

# Prints a clear error message, gives the user time to read it, then terminates the script with a non-zero code.
function Exit-Error {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [int]$TimeoutSeconds = 20
    )
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Write-Host ""
    Write-Host "Closing in $TimeoutSeconds seconds. Press any key to close immediately."
    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopWatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if ([System.Console]::KeyAvailable) {
            [System.Console]::ReadKey($true) | Out-Null
            break
        }
        Start-Sleep -Milliseconds 100
    }
    Exit 1
}

# INF-parsing logic
Import-Module (Join-Path $PSScriptRoot "NetPrinterInstallParser.psm1")

$ConfigFileName = Join-Path $PSScriptRoot "NetPrinterInstallConfig.xml"

if (-not (Test-Path -Path $ConfigFileName)) {
    # Config file missing; enter Setup immediately.
    $Setup = $true
} else {
    # Config file exists; proceed with installation
    $Setup = $false

    # Check for Administrator privileges; if not, auto-elevate.
    $AdminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $AdminRights) {
        Write-Host "Restarting with Administrator rights..."

        # Script's absolute path (works locally and on UNC shares),
        $ScriptPath = $PSCommandPath
        if ([string]::IsNullOrEmpty($ScriptPath)) { $ScriptPath = $MyInvocation.MyCommand.Path }

        $ElevatedArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $args

        Start-Process -FilePath 'powershell.exe' -ArgumentList $ElevatedArgs -Verb RunAs
        Exit
    }

    # Now that we're running as Administrator, wait 5 seconds.
    # If a key is pressed during this time, activate Setup mode.
    $timeout = 5
    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host "The new printer installation will start automatically in $timeout seconds."
    Write-Host "Press any key to enter Setup (cancel the installation)."
    while ($stopWatch.Elapsed.TotalSeconds -lt $timeout) {
        if ([System.Console]::KeyAvailable) {
            # Key pressed: read it and activate Setup.
            [System.Console]::ReadKey($true) | Out-Null
            $Setup = $true
            break
        }
        Start-Sleep -Milliseconds 100
    }
    $stopWatch.Stop()
}

If ($Setup) {
    #https://github.com/Sebazzz/PSMenu
    Import-Module (Join-Path $PSScriptRoot "PSMenu\PSMenu.psm1")

    [xml]$configFile = "<?xml version=`"1.0`"?><Settings><Add><Address></Address><Name></Name><Driver></Driver><InfPath></InfPath><Default></Default><Color></Color><DuplexingMode></DuplexingMode></Add><Remove><Printer></Printer><Port></Port></Remove></Settings>"

    Write-Host "This setup will generate a new configuration file."
    Write-Host "Before proceeding, copy the folder containing the new printer drivers to the same location as this script."
    Write-Host "After setup, running this script again will install the printer automatically."
    Write-Host ""

    #Find default adapter IP address (for later auto-suggestion)
    $IPAddress = ( Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -ne "Disconnected" } | Select-Object -First 1 ).IPv4Address.IPAddress
    if ([string]::IsNullOrEmpty($IPAddress)) {
        # No active adapter found
        $IPAddress = ""
    } else {
        $Bits = [System.Collections.Generic.List[System.Object]]$IPAddress.Split(".")
        $Bits.RemoveAt(3)
        $IPAddress = ""
        $Bits | ForEach { $IPAddress += "$($_)." }
    }

    #Suggestion script block
    $Suggestion = {
        Start-Sleep -Milliseconds 1
        $WScriptShell = New-Object -com WScript.Shell
        $WScriptShell.SendKeys($args[0])   
    }

    #Suggest ip address
    Start-Job $Suggestion -ArgumentList $IPAddress | Out-Null
    $configFile.Settings.Add.Address = [string](Read-Host -Prompt "Enter printer TCP/IP address")
    Write-Host ""

    #Search for drivers
    $Drivers = @()
    While ($Drivers.Count -eq 0 ) {
        $SearchTerm = Read-Host -Prompt "Enter a small part of the model number, then select the right driver"
        Get-ChildItem -Path $PSScriptRoot -Filter "*.inf" -Recurse | ForEach {
            $infFullPath = $_.FullName
            # Path relative to $PSScriptRoot
            $infPath = $infFullPath.Substring($PSScriptRoot.TrimEnd('\','/').Length).TrimStart('\','/')

            # Skip INFs that aren't actual printer drivers (e.g. Class=USB or Class=Ports stubs)
            If (-not (Test-IsPrinterInf -Path $infFullPath)) { return }

            # Get-InfDriverNames returns both directly-quoted names and %Token% names resolved via [Strings] (e.g. PRINTER1="...").
            Get-InfDriverNames -Path $infFullPath | ForEach {
                #Match user search
                If ( $_ -match $SearchTerm ) {
                    $Drivers += [PSCustomObject]@{
                        Name = $_
                        InfPath = $infPath
                    }
                }
            }
        }
        If ( $Drivers.Count -eq 0 ) {
            Write-Host "No driver found for *$($SearchTerm)* in any subfolders. Please try again."
            Write-Host ""
        }
    }

    #Create menu for user selection
    $MenuList = @()
    $MaxLength = $Host.UI.RawUI.MaxWindowSize.Width - 55
    $Drivers | ForEach {
        $MenuItem = "$($_.Name) ($($_.InfPath))"
        #Try to avoid Show-Menu mess with long menu entries
        If ( $MenuItem.Length -gt $MaxLength ) { $MenuItem = $MenuItem.Substring( 0, $MaxLength) }
        $MenuList += $MenuItem
    }
    $Chosen = Show-Menu -MenuItems $MenuList -ReturnIndex
    $configFile.Settings.Add.Driver = [string]$Drivers[$Chosen].Name
    $configFile.Settings.Add.InfPath = [string]$Drivers[$Chosen].InfPath
    #Write-Host ""

    #Try to clean Show-Menu mess in some conditions
    $strPad = " ".PadLeft( $Host.UI.RawUI.MaxWindowSize.Width - 1 , ' ' )
    Write-Host $strPad
    Write-Host $strPad -NoNewline
    $Host.UI.RawUI.CursorPosition = @{ x = 0; y = $Host.UI.RawUI.CursorPosition.Y }

    #Get Settings.Add.Name
    Start-Job $Suggestion -ArgumentList $configFile.Settings.Add.Driver | Out-Null
    $configFile.Settings.Add.Name = [string](Read-Host -Prompt "Enter printer name")
    Write-Host ""

    #Get Settings.Add.Default
    Write-Host "Do you want to set the new printer as default?"
    $Chosen = Show-Menu @("No", "Yes") -ReturnIndex
    $configFile.Settings.Add.Default = [string]$Chosen
    Write-Host ""

    Write-Host "Do you want to do any additional settings (Duplexing mode and Color)?"
    Write-Host "This is not guaranteed to work with all drivers."
    $Chosen = Show-Menu @("No", "Yes") -ReturnIndex
    If ($Chosen) {
        Write-Host ""
        #Get Settings.Add.DuplexingMode
        Write-Host "Please select Duplexing mode. Press ESC to skip this step."
        $Chosen = Show-Menu @('OneSided','TwoSidedLongEdge','TwoSidedShortEdge')
        $configFile.Settings.Add.DuplexingMode = [string]$Chosen   
        Write-Host ""
        #Get Settings.Add.Color
        Write-Host "Please select Color mode. Press ESC to skip this step."
        $Chosen = Show-Menu @('Grayscale','Color') -ReturnIndex
        $configFile.Settings.Add.Color = [string]$Chosen 
    }
    Write-Host ""
    
    Write-Host "Do you want to remove any old printers or ports?"
    $Chosen = Show-Menu @("No", "Yes") -ReturnIndex
    If ($Chosen) {
        Write-Host ""
        #Get Settings.Remove.Port
        Write-Host "Enter part of the name of the PORT to remove."
        Write-Host "Be more specific as possible, because ALL PORTS MATCHING PART OF THIS NAME WILL BE REMOVED."
        Write-Host "Enter an empty name to skip this step"
        $configFile.Settings.Remove.Port = [string](Read-Host -Prompt "Remove port")
        Write-Host ""

        #Get Settings.Remove.Printer
        Write-Host "Enter part of the name of the PRINTER to remove."
        Write-Host "Be more specific as possible, because ALL PRINTERS MATCHING PART OF THIS NAME WILL BE REMOVED."
        Write-Host "Enter an empty name to skip this step"
        $configFile.Settings.Remove.Printer = [string](Read-Host -Prompt "Remove printer")
    }
    Write-Host ""
    
    $configFile.Save($ConfigFileName)
    Write-Host -ForeGroundColor Green "Configuration file written to $($ConfigFileName)."
    Write-Host ""
    Write-Host "Running this script again will install the printer automatically."
    Start-Sleep -Seconds 5
    Exit
} Else {    
    [xml]$configFile = Get-Content -Path $ConfigFileName

    Write-Host ""

    # Phase 1: Remove old printers/ports
    If ($configFile.Settings.Remove.Printer -ne "") {
        Get-Printer | Where Name -match $configFile.Settings.Remove.Printer | ForEach {
            Write-Host "Removing printer $($_.Name)..."
            Remove-Printer -Name $_.Name
        }
    } 

    If ($configFile.Settings.Remove.Port -ne "") {
        Get-PrinterPort | Where Name -match $configFile.Settings.Remove.Port | ForEach {
            Write-Host "Removing port $($_.Name)..."
            Remove-PrinterPort -Name $_.Name
        }
    }

    # Phase 2: Driver install
    # pnputil.exe return codes
    $PNPUTIL_SUCCESS = 0
    $PNPUTIL_NO_MORE_ITEMS = 259          #not a real error

    $DriverFile = Join-Path $PSScriptRoot $configFile.Settings.Add.InfPath
    Write-Host "Installing driver package via pnputil..."
    try {
        $pnputilOutput = & pnputil.exe /add-driver "$DriverFile" /install 2>&1
        $pnputilExitCode = $LASTEXITCODE
        switch ($pnputilExitCode) {
            $PNPUTIL_SUCCESS { Write-Host "Driver package installed successfully." }
            $PNPUTIL_NO_MORE_ITEMS { Write-Host "Driver package was already present in the driver store, continuing." -ForegroundColor Yellow }
            default { Exit-Error "pnputil failed to install the driver package '$DriverFile' (exit code $pnputilExitCode).`n$($pnputilOutput | Out-String)" }
        }
    } catch {
        Exit-Error "pnputil failed to install the driver package '$DriverFile'.`n$_"
    }

    Write-Host "Registering printer driver '$($configFile.Settings.Add.Driver)'..."
    try {
        # Always call Add-PrinterDriver, even if a driver with this name is already registered: pnputil above may have just updated the driver package 
        Add-PrinterDriver -Name $configFile.Settings.Add.Driver -ErrorAction Stop
        Write-Host "Printer driver registered successfully."
    } catch {
        $StillMissing = -not (Get-PrinterDriver -Name $configFile.Settings.Add.Driver -ErrorAction SilentlyContinue)
        if ($StillMissing) {
            Exit-Error "Add-PrinterDriver failed for driver '$($configFile.Settings.Add.Driver)' (HResult 0x$($_.Exception.HResult.ToString('X8'))).`n$_"
        } else {
            Write-Host "Printer driver was already registered (or is now present), continuing." -ForegroundColor Yellow
        }
    }

    # Phase 3: Port setup
    $PortName = "IP_$($configFile.Settings.Add.Address)"
    $ExistingPort = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
    if ($ExistingPort) {
        # Check existence up front instead of parsing the error afterwards
        Write-Host "Port '$PortName' already exists, continuing." -ForegroundColor Yellow
    } else {
        Write-Host "Creating new port '$PortName'..."
        try {
            Add-PrinterPort -Name $PortName -PrinterHostAddress $configFile.Settings.Add.Address -ErrorAction Stop
            Write-Host "Port created successfully."
        } catch {
            Exit-Error "Add-PrinterPort failed to create port '$PortName' (HResult 0x$($_.Exception.HResult.ToString('X8'))).`n$_"
        }
    }

    # Phase 4: Printer setup
    $ExistingPrinter = Get-Printer -Name $configFile.Settings.Add.Name -ErrorAction SilentlyContinue
    if ($ExistingPrinter) {
        Write-Host "Printer '$($configFile.Settings.Add.Name)' already exists, updating its driver and port..." -ForegroundColor Yellow
        try {
            Set-Printer -Name $configFile.Settings.Add.Name -DriverName $configFile.Settings.Add.Driver -PortName $PortName -ErrorAction Stop
            Write-Host "Printer updated successfully."
        } catch {
            Exit-Error "Set-Printer failed to update printer '$($configFile.Settings.Add.Name)'.`n$_"
        }
    } else {
        Write-Host "Installing printer '$($configFile.Settings.Add.Name)'..."
        try {
            Add-Printer -Name $($configFile.Settings.Add.Name) -DriverName $configFile.Settings.Add.Driver -PortName $PortName -ErrorAction Stop
            Write-Host "Printer installed successfully."
        } catch {
            Exit-Error "Add-Printer failed to install printer '$($configFile.Settings.Add.Name)'.`n$_"
        }
    }

    # Phase 5: Printer configuration
    If ($configFile.Settings.Add.Color -ne "") {
        Write-Host "Configuring Color..."
        Set-PrintConfiguration -PrinterName $($configFile.Settings.Add.Name) -Color ($configFile.Settings.Add.Color -eq "1")
    }

    If ($configFile.Settings.Add.DuplexingMode -ne "") {
        Write-Host "Configuring DuplexingMode to $($configFile.Settings.Add.DuplexingMode)..."
        Set-PrintConfiguration -PrinterName $($configFile.Settings.Add.Name) -DuplexingMode $configFile.Settings.Add.DuplexingMode
    }

    If ($configFile.Settings.Add.Default -eq "1") {
        Write-Host "Setting default printer..."
        (New-Object -ComObject WScript.Network).SetDefaultPrinter($($configFile.Settings.Add.Name))
    }
    Write-Host ""
    Write-Host "Done. Closing in 5 seconds."
    Start-Sleep -Seconds 5
}