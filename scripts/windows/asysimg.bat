@echo off
set julia=julia.exe
for /f "tokens=1-4" %%i in ('%julia% -e "using AutoSysimages; print(julia_args()); exit()"') do set A=%%i %%j %%k %%l
@"%~dp0\julia.exe" %A% %*
