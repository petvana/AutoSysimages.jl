# [Faster compilation (experimental)](@id chained_build)

The process of building the whole monolithic system image (sysimamge) takes several minutes. However, most of the functions are already compiled into the binary code in the original sysimage shipped with Julia. It seems possible to compile only newly introduced function and user-specific precompile statements that speed-up the building process significantly. Be aware this chained compilation is very experimental.

## **Warning very experimental**
**The chained sysimage build is currently expected to work only on Ubuntu operation system.**

You can try that by compiling branch [petvana:pv/fastsysimg](https://github.com/petvana/julia/tree/pv/fastsysimg) from source.

For more details, please read this [PR #46045](https://github.com/JuliaLang/julia/pull/46045).

## How to test chained sysimages

On Ubuntu, you can modify `scripts/linux/asysimg` script in `~/.local/bin/asysimg` by including path to the directory where you compiled the branch.

``` bash
#!/usr/bin/env bash
JULIA_EXE=[INSERT-YOUR-PATH-TO-petvana:pv/fastsysimg-BRANCH]/julia
asysimg_args=`$JULIA_EXE -e "using AutoSysimages; print(julia_args()); exit();" "$@"`
$JULIA_EXE $asysimg_args "$@"
```