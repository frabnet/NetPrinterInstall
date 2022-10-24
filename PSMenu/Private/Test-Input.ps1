# Ref: https://docs.microsoft.com/en-us/windows/desktop/inputdev/virtual-key-codes
$KeyConstants = [PSCustomObject]@{
    VK_RETURN   = 0x0D;
    VK_ESCAPE   = 0x1B;
    VK_UP       = 0x26;
    VK_DOWN     = 0x28;
    VK_SPACE    = 0x20;
    VK_PAGEUP   = 0x21; # Actually VK_PRIOR
    VK_PAGEDOWN = 0x22; # Actually VK_NEXT
    VK_END      = 0x23;
    VK_HOME     = 0x24;
}

function Test-KeyEnter($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_RETURN
}

function Test-KeyEscape($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_ESCAPE
}

function Test-KeyUp($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_UP
}

function Test-KeyDown($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_DOWN
}

function Test-KeySpace($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_SPACE
}

function Test-KeyPageDown($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_PAGEDOWN
}

function Test-KeyPageUp($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_PAGEUP
}

function Test-KeyEnd($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_END
}

function Test-KeyHome($VKeyCode) {
    Return $VKeyCode -eq $KeyConstants.VK_HOME
}
