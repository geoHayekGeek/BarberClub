@echo off
REM Test deep link on Android emulator/device
REM Usage: test_deep_link.bat [token] [email]
REM Example: test_deep_link.bat test123 test@example.com

set TOKEN=%1
set EMAIL=%2

if "%TOKEN%"=="" set TOKEN=test123
if "%EMAIL%"=="" set EMAIL=test@example.com

echo Testing deep link: barberclub://reset-password?token=%TOKEN%^&email=%EMAIL%
adb shell am start -a android.intent.action.VIEW -d "barberclub://reset-password?token=%TOKEN%&email=%EMAIL%"
