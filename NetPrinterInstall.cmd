@echo off
pushd %~dp0
powershell.exe -NoProfile -Executionpolicy Bypass -Command "Clear; Set-Location '%~dp0' ; .\%~n0.ps1 %*"
popd