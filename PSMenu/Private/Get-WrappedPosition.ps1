function  Get-WrappedPosition([Array]$MenuItems, [int]$Position, [int]$PositionOffset) {
    # Wrap position
    if ($Position -lt 0) {
        $Position = $MenuItems.Count - 1
    }

    if ($Position -ge $MenuItems.Count) {
        $Position = 0
    }

    # Ensure to skip separators
    while (Test-MenuSeparator $($MenuItems[$Position])) {
        $Position += $PositionOffset

        $Position = Get-WrappedPosition $MenuItems $Position $PositionOffset
    }

    Return $Position
}
