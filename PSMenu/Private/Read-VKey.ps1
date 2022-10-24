function Read-VKey() {
    $CurrentHost = Get-Host
    $ErrMsg = "Current host '$CurrentHost' does not support operation 'ReadKey'"

    try {
         # Issues with reading up and down arrow keys
         # - https://github.com/PowerShell/PowerShell/issues/16443
         # - https://github.com/dotnet/runtime/issues/63387
         # - https://github.com/PowerShell/PowerShell/issues/16606
         if ($IsLinux -or $IsMacOS) {
            ## A bug with Linux and Mac where arrow keys are return in 2 chars.  First is esc follow by A,B,C,D
            $key1 = $CurrentHost.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            if ($key1.VirtualKeyCode -eq 0x1B) {
               ## Found that we got an esc chair so we need to grab one more char
               $key2 = $CurrentHost.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

               ## We just care about up and down arrow mapping here for now.
                if ($key2.VirtualKeyCode -eq 0x41) {
                    # VK_UP = 0x26 up-arrow
                    $key1.VirtualKeyCode = 0x26
                }
                if ($key2.VirtualKeyCode -eq 0x42) {
                    # VK_DOWN = 0x28 down-arrow
                    $key1.VirtualKeyCode = 0x28
                }
            }
            Return $key1
        }
        
        Return $CurrentHost.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    catch [System.NotSupportedException] {
        Write-Error -Exception $_.Exception -Message $ErrMsg
    }
    catch [System.NotImplementedException] {
        Write-Error -Exception $_.Exception -Message $ErrMsg
    }
}
