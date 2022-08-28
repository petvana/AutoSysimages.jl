#!/usr/bin/env bash

# Thish removes all files produced by AutoSysimages.jl
rm -rf ~/.julia/asysimg/

rm -f ~/.julia/environments/v*/SysimagePreferences.toml
rm -f examples/*/SysimagePreferences.toml
