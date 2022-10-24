<#

.SYNOPSIS
Shows an interactive menu to the user and returns the chosen item or item index.

.DESCRIPTION
Shows an interactive menu on supporting console hosts. The user can interactively
select one (or more, in case of -MultiSelect) items. The cmdlet returns the items
itself, or its indices (in case of -ReturnIndex). 

The interactive menu is controllable by hotkeys:
- Arrow up/down: Focus menu item.
- Enter: Select menu item.
- Page up/down: Go one page up or down - if the menu is larger then the screen.
- Home/end: Go to the top or bottom of the menu.
- Spacebar: If in multi-select mode (MultiSelect parameter), toggle item choice.

Not all console hosts support the interactive menu (PowerShell ISE is a well-known
host which doesn't support it). The console host needs to support the ReadKey method.
The default PowerShell console host does this. 

.PARAMETER  MenuItems
Array of objects or strings containing menu items. Must contain at least one item.
Must not contain $null. 

The items are converted to a string for display by the MenuItemFormatter parameter, which
does by default a ".ToString()" of the underlying object. It is best for this string 
to fit on a single line.

The array of menu items may also contain unselectable separators, which can be used
to visually distinct menu items. You can call Get-MenuSeparator to get a separator object,
and add that to the menu item array.

.PARAMETER  ReturnIndex
Instead of returning the object(s) that has/have been chosen, return the index/indices
of the object(s) that have been chosen.

.PARAMETER  MultiSelect
Allow the user to select multiple items instead of a single item.

.PARAMETER  ItemFocusColor
The console color used for focusing the active item. This by default green,
which looks good on both default PowerShell-blue and black consoles.

.PARAMETER  MenuItemFormatter
A function/scriptblock which accepts a menu item (from the MenuItems parameter)
and returns a string suitable for display. This function will be called many times,
for each menu item once.

This parameter is optional and by default executes a ".ToString()" on the object.
If you control the objects that you pass in MenuItems, then you want to probably
override the ToString() method. If you don't control the objects, then this parameter
is very useful.

.PARAMETER InitialSelection
Set initial selections if multi-select mode. This is an array of indecies.

.PARAMETER Callback
A function/scriptblock which is called every 10 milliseconds while the menu is shown

.INPUTS

None. You cannot pipe objects to Show-Menu.

.OUTPUTS

Array of chosen menu items or (if the -ReturnIndex parameter is given) the indices.

.LINK

https://github.com/Sebazzz/PSMenu

.EXAMPLE

Show-Menu @("option 1", "option 2", "option 3")

.EXAMPLE 

Show-Menu -MenuItems $(Get-NetAdapter) -MenuItemFormatter { $Args | Select -Exp Name }

.EXAMPLE 

Show-Menu @("Option A", "Option B", $(Get-MenuSeparator), "Quit")

#>
function Show-Menu {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, Position = 0)][Array] $MenuItems,
        [Switch]$ReturnIndex, 
        [Switch]$MultiSelect, 
        [ConsoleColor] $ItemFocusColor = [ConsoleColor]::Green,
        [ScriptBlock] $MenuItemFormatter = { Param($M) Format-MenuItemDefault $M },
        [Array] $InitialSelection = @(),
        [ScriptBlock] $Callback = $null
    )

    Test-HostSupported
    Test-MenuItemArray -MenuItems $MenuItems

    # Current pressed virtual key code
    $VKeyCode = 0

    # Initialize valid position
    $Position = Get-WrappedPosition $MenuItems -Position 0 -PositionOffset 1

    $CurrentSelection = $InitialSelection
    
    try {
        [System.Console]::CursorVisible = $False # Prevents cursor flickering

        # Body
        $WriteMenu = {
            ([ref]$MenuHeight).Value = Write-Menu -MenuItems $MenuItems `
                -MenuPosition $Position `
                -MultiSelect:$MultiSelect `
                -CurrentSelection:$CurrentSelection `
                -ItemFocusColor $ItemFocusColor `
                -MenuItemFormatter $MenuItemFormatter
        }
        $MenuHeight = 0

        & $WriteMenu
        $NeedRendering = $false
        
        While ($True) {
            If (Test-KeyEscape $VKeyCode) {
                Return $null
            }

            If (Test-KeyEnter $VKeyCode) {
                Break
            }

            # While there are 
            Do {
                # Read key when callback and available key, or no callback at all
                $VKeyCode = $null
                if ($null -eq $Callback -or [Console]::KeyAvailable) {
                    $CurrentPress = Read-VKey
                    $VKeyCode = $CurrentPress.VirtualKeyCode
                }

                If (Test-KeySpace $VKeyCode) {
                    $CurrentSelection = Toggle-Selection $Position $CurrentSelection
                }

                $Position = Get-PositionWithVKey -MenuItems $MenuItems -Position $Position -VKeyCode $VKeyCode

                If (!$(Test-KeyEscape $VKeyCode)) {
                    [System.Console]::SetCursorPosition(0, [Math]::Max(0, [Console]::CursorTop - $MenuHeight))
                    $NeedRendering = $true
                }
            } While ($null -eq $Callback -and [Console]::KeyAvailable);

            If ($NeedRendering) {
                & $WriteMenu
                $NeedRendering = $false
            }

            If ($Callback) {
                & $Callback

                Start-Sleep -Milliseconds 10
            }
        }
    }
    finally {
        [System.Console]::CursorVisible = $true
    }

    if ($ReturnIndex -eq $false -and $null -ne $Position) {
        if ($MultiSelect) {
            if ($null -ne $CurrentSelection) {
                Return $MenuItems[$CurrentSelection]
            }
        }
        else {
            Return $MenuItems[$Position]
        }
    }
    else {
        if ($MultiSelect) {
            Return $CurrentSelection
        }
        else {
            Return $Position
        }
    }
}
