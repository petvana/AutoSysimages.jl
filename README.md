# AutoSysimages.jl
This package automates building of user-specific system images (sysimages) for the specific project.  

[![docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://petvana.github.io/AutoSysimages.jl)
[![Build Status](https://github.com/petvana/AutoSysimages.jl/workflows/Runtests/badge.svg)](https://github.com/petvana/AutoSysimages.jl/actions/workflows/Runtests.yml)

## Basic example with Plots

[![asciicast](https://asciinema.org/a/ivg6l4VS2XckGop1tsXGkPxn1.svg)](https://asciinema.org/a/ivg6l4VS2XckGop1tsXGkPxn1)

## Main features
- Automatically stores precompile statements for the given project.
- Single command build process by `build_sysimage()`.
- Removes old unused sysimages.
- Warns if the loaded sysimage contains outdated packages (Julia v1.8+).

Please see the documentation for more details.

### Thanks

This project has been supported by **Google Summer of Code 2022**.