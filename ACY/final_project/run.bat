@echo off
if exist "%~dp0love-11.5-win64\lovec.exe" (
  "%~dp0love-11.5-win64\lovec.exe" "%~dp0project\src"
) else if exist "%~dp0..\..\love-11.5-win64\lovec.exe" (
  "%~dp0..\..\love-11.5-win64\lovec.exe" "%~dp0project\src"
) else (
  love "%~dp0project\src"
)

