
Write-Verbose "Importing Functions..."

# Import everything in these folders
foreach ($Folder in @('Private', 'Public', 'Classes')) {
    $RootFolder = Join-Path -Path $PSScriptRoot -ChildPath $Folder

    if (Test-Path -Path $RootFolder) {
        Write-Verbose "`tProcessing folder $RootFolder"
        $Files = Get-ChildItem -Path $RootFolder -Filter *.ps1

        # dot source each file
        $Files | Where-Object { $_.name -NotLike '*.Tests.ps1' } | ForEach-Object { Write-Verbose "`t`t$($_.name)"; . $_.FullName }
    }
}

Export-ModuleMember -Function (Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1").BaseName