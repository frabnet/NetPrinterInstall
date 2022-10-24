function Test-HostSupported() {
    $Whitelist = @("ConsoleHost")

    if ($Whitelist -inotcontains $Host.Name) {
        Throw "This host is $($Host.Name) and does not support an interactive menu."
    }
}