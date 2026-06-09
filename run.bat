@echo off
if exist "love-11.5-win64\lovec.exe" (
    "love-11.5-win64\lovec.exe" "project\src"
) else if exist "WithAi\love-11.5-win64\lovec.exe" (
    cd WithAi
    "love-11.5-win64\lovec.exe" "project\src"
) else (
    echo Error: love-11.5-win64 folder not found.
    pause
)