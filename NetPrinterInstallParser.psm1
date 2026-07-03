# NetPrinterInstallParser.psm1
# Helpers to parse printer driver INF files: filter real printer INFs and
# extract driver friendly names, including those defined via %Token%
# substitution in the [Strings] / [Strings.xxxx] sections (common in many
# HP/vendor INFs) instead of being quoted directly in the model section.

function Test-IsPrinterInf {
    # Reads "Class=" in [Version] to discard non-printer INF stubs (e.g. Class=USB, Class=Ports).
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    $classLine = Get-Content -Path $Path -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '^\s*Class\s*=\s*([^\s;]+)' } |
        Select-Object -First 1
    if ($classLine -match '^\s*Class\s*=\s*([^\s;]+)') {
        return ($Matches[1].Trim() -ieq 'Printer')
    }
    return $false
}

function Get-InfStringsTable {
    # Parses [Strings] and localized [Strings.xxxx] sections into a Token -> Value hashtable.
    param(
        # Not Mandatory: a Mandatory array parameter rejects an empty array with a
        # (misleadingly worded) "empty string" binding error, which real INF files can trigger.
        [AllowEmptyCollection()]
        [string[]]$Content = @()
    )
    $table = @{}
    $inStrings = $false
    foreach ($line in $Content) {
        if ($line -match '^\s*\[Strings(\.\w+)?\]\s*$') { $inStrings = $true; continue }
        if ($line -match '^\s*\[.+\]\s*$') { $inStrings = $false; continue }
        if ($inStrings -and $line -match '^\s*([^=;]+?)\s*=\s*"(.*)"\s*$') {
            # Later [Strings.xxxx] sections overwrite the default [Strings] ones, which is fine.
            $table[$Matches[1].Trim()] = $Matches[2]
        }
    }
    return $table
}

function Get-InfDriverNames {
    # Returns all printer driver friendly names in an INF: both directly-quoted
    # names and %Token% names resolved through Get-InfStringsTable.
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    $content = Get-Content -Path $Path -ErrorAction SilentlyContinue
    if (-not $content) { return @() }

    $strings = Get-InfStringsTable -Content $content
    $names = New-Object System.Collections.Generic.List[string]
    $section = ""

    foreach ($line in $content) {
        if ($line -match '^\s*\[(.+)\]\s*$') { $section = $Matches[1]; continue }
        # Skip [Manufacturer]: it maps OEM name to model-list sections, not an actual driver name.
        if ($section -ieq 'Manufacturer') { continue }

        # Case 1: "Driver Name" = Section,HWID  (name quoted directly)
        if ($line -match '^\s*"([^"]+)"\s*=') {
            $names.Add($Matches[1])
            continue
        }
        # Case 2: %Token% = Section,HWID  (name defined in [Strings] as Token="...")
        if ($line -match '^\s*%([^%]+)%\s*=') {
            $token = $Matches[1]
            if ($strings.ContainsKey($token)) {
                $names.Add($strings[$token])
            }
        }
    }

    return $names | Select-Object -Unique
}

Export-ModuleMember -Function Test-IsPrinterInf, Get-InfStringsTable, Get-InfDriverNames