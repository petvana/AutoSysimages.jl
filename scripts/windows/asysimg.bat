@echo off
for /f "tokens=1-4" %%i in ('julia.exe -e "using AutoSysimages; print(julia_args()); exit()"') do set A=%%i %%j %%k %%l 
@"%~dp0\julia.exe" %A% %*