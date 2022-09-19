@echo off
set JULIA=julia.exe
for /f "tokens=1-4" %%i in ('%JULIA% -e "using AutoSysimages; print(julia_args()); exit()"') do set A=%%i %%j %%k %%l
%JULIA% %A% %*
