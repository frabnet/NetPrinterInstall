function Test-MenuItemArray([Array]$MenuItems) {
    foreach ($MenuItem in $MenuItems) {
        $IsSeparator = Test-MenuSeparator $MenuItem
        if ($IsSeparator -eq $false) {
            Return
        }
    }

    Throw 'The -MenuItems option only contains non-selectable menu-items (like separators)'
}