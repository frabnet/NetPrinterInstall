function Get-ConsoleHeight() {
    Return (Get-Host).UI.RawUI.WindowSize.Height - 2
}