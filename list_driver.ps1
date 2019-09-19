$dirs = Get-ChildItem -Directory
ForEach ($dir in $dirs)
{
	Write-Host ""
	Write-Host "Searching in: $dir" -ForegroundColor Yellow -BackgroundColor DarkBlue
	Get-ChildItem "$dir\*.inf" | Select-String '" = '
	Get-ChildItem "$dir\*.inf" | Select-String 'PRINTER1 = "' 
}
