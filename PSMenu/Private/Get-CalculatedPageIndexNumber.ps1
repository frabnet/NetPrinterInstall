function Get-CalculatedPageIndexNumber(
    [Parameter(Mandatory, Position = 0)][Array] $MenuItems,
    [Parameter(Position = 1)][int]$MenuPosition,
    [Switch]$TopIndex,
    [Switch]$ItemCount,
    [Switch]$BottomIndex
) {
    $WindowHeight = Get-ConsoleHeight

    $TopIndexNumber = 0;
    $MenuItemCount = $MenuItems.Count

    if ($MenuItemCount -gt $WindowHeight) {
        $MenuItemCount = $WindowHeight;
        if ($MenuPosition -gt $MenuItemCount) {
            $TopIndexNumber = $MenuPosition - $MenuItemCount;
        }
    }

    if ($TopIndex) {
        Return $TopIndexNumber
    }

    if ($ItemCount) {
        Return $MenuItemCount
    }

    if ($BottomIndex) {
        Return $TopIndexNumber + [Math]::Min($MenuItemCount, $WindowHeight) - 1
    }

    Throw 'Invalid option combination'
}