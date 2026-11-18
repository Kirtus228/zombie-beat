@echo off
rem Записать 12 секунд игры в PNG-последовательность, чтобы посмотреть кадры без окна.
rem Использование: record.cmd [секунды]
set SEC=%1
if "%SEC%"=="" set SEC=12
del /q "%~dp0movie\*.png" 2>nul
"D:\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --write-movie "%~dp0movie\frame.png" --fixed-fps 30 --quit-after %SEC% --disable-vsync
