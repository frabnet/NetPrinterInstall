Write-Host "NetPrinterInstall v2.0" -ForegroundColor Green 
Write-Host "https://github.com/frabnet/NetPrinterInstall" -ForegroundColor Green
Write-Host "---"
Write-Host ""

$ConfigFileName = "NetPrinterInstallConfig.xml"

$Setup = $False
#Check for config file presence
If (Test-Path -Path $ConfigFileName) {
    $Timeout = 5
    $Sec = $Timeout
    While ( (-Not $Host.UI.RawUI.KeyAvailable) -And  ($Sec -gt 0 )) {
        Write-Host "Setup of the new printer will start in $($Sec) seconds."
        Write-Host "Press any key to enter Setup, or close this window to abort."
        (Get-Host).UI.RawUI.CursorPosition = @{ x = 0; y = (Get-Host).UI.RawUI.CursorPosition.Y-2 }
        Sleep 1
        $Sec--
    }
    Write-Host ""
    Write-Host ""
    Write-Host ""
    $Setup = ($Sec -gt 0)
    If ($Setup) { $Dummy = $host.UI.RawUI.ReadKey("NoEcho, IncludeKeyUp") }
} Else {
    $Setup = $True  
}

If ($Setup) {
    #https://github.com/Sebazzz/PSMenu
    Import-Module .\PSMenu\PSMenu.psm1

    [xml]$configFile = "<?xml version=`"1.0`"?><Settings><Add><Address></Address><Name></Name><Driver></Driver><InfPath></InfPath><Default></Default><Color></Color><DuplexingMode></DuplexingMode></Add><Remove><Printer></Printer><Port></Port></Remove></Settings>"

    Write-Host "This setup will generate a new configuration file."
    Write-Host "Before proceeding, copy the folder containing the new printer drivers to the same location as this script."
    Write-Host "After setup, running this script again will install the printer automatically."
    Write-Host ""

    #Find default adapater IP address (for later auto-suggestion)
    $IPAddress = ( Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -ne "Disconnected" } | Select-Object -First 1 ).IPv4Address.IPAddress
    $Bits = [System.Collections.Generic.List[System.Object]]$IPAddress.Split(".")
    $Bits.RemoveAt(3)
    $IPAddress = ""
    $Bits | ForEach { $IPAddress += "$($_)." }

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
        $searchTerm = Read-Host -Prompt "Enter a small part of the model number, then select the right driver"
        Get-ChildItem -Path "*.inf" -Recurse | ForEach { 
            $infPath = $_.FullName | Resolve-Path -Relative
            Get-Content $infPath | ForEach {
                #Match a printer driver
                If ( $_ -Match ('(?<=")(.*?)(?="[ =])') ) {
                    $Driver = $Matches.0
                    #Match user search
                    If ($Driver -match $SearchTerm) {                    
                        $Drivers += [PSCustomObject]@{
                            Name = $($Driver)
                            InfPath = $($infPath)
                        }
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
    $Drivers | ForEach { $MenuList += "$($_.Name) ($($_.InfPath))" }
    $Chosen = Show-Menu -MenuItems $MenuList -ReturnIndex
    $configFile.Settings.Add.Driver = [string]$Drivers[$Chosen].Name
    $configFile.Settings.Add.InfPath = [string]$Drivers[$Chosen].InfPath
    #Write-Host ""

    #Try to clean Show-Menu mess in some conditions
    $strPad = " ".PadLeft( (Get-Host).UI.RawUI.MaxWindowSize.Width - 1 , ' ' )
    Write-Host $strPad
    Write-Host $strPad -NoNewline
    (Get-Host).UI.RawUI.CursorPosition = @{ x = 0; y = (Get-Host).UI.RawUI.CursorPosition.Y }

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
    $AdminRights = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    If (!$AdminRights) {
        Write-Host "Restarting with Administrator rights..."
        $CmdLine = "Set-Location '$($PSScriptRoot)' ; .\$($MyInvocation.InvocationName) $($args)"
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -Command ""$($CmdLine)""" -Verb RunAs
        Exit
    }
    
    [xml]$configFile = Get-Content -Path $ConfigFileName

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

    Write-Host "Installing driver..."    
    Start-Process -Wait -FilePath "pnputil.exe" -ArgumentList "/add-driver ""$($configFile.Settings.Add.InfPath)"" /install"
    Add-PrinterDriver -Name $configFile.Settings.Add.Driver

    Write-Host "Creating new port..."
    Add-PrinterPort -Name "IP_$($configFile.Settings.Add.Address)" -PrinterHostAddress $configFile.Settings.Add.Address -ErrorAction SilentlyContinue

    Write-Host "Installing printer..."
    Add-Printer -Name $($configFile.Settings.Add.Name) -DriverName $configFile.Settings.Add.Driver -PortName "IP_$($configFile.Settings.Add.Address)"

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