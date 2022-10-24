$Separator = [PSCustomObject]@{
    __MarkSeparator = [Guid]::NewGuid()
}

<#

.SYNOPSIS 

Returns a separator for the Show-Menu Cmdlet. The separator is not selectable by the user and
allows a visual distinction of multiple menuitems.

.EXAMPLE

$MenuItems = @("Option A", "Option B", $(Get-MenuSeparator), "Quit")
Show-Menu $MenuItems

#>
function Get-MenuSeparator() {
    [CmdletBinding()]
    Param()

    # Internally we will check this parameter by-reference
    Return $Separator
}