var documenterSearchIndex = {"docs":
[{"location":"api/#API-Documentation","page":"API Documentation","title":"API Documentation","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"Docstrings for AutoSysimages.jl interface members can be accessed through Julia's built-in documentation system or in the list below.","category":"page"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"CurrentModule = AutoSysimages","category":"page"},{"location":"api/#Contents","page":"API Documentation","title":"Contents","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"Pages = [\"api.md\"]","category":"page"},{"location":"api/#Index","page":"API Documentation","title":"Index","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"Pages = [\"api.md\"]","category":"page"},{"location":"api/#Functions","page":"API Documentation","title":"Functions","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"start\nlatest_sysimage\njulia_args\nbuild_sysimage\nremove_old_sysimages\npackages_to_include\nselect_packages\nstatus\nadd\nremove\nactive_dir\npreferences_path","category":"page"},{"location":"api/#AutoSysimages.start","page":"API Documentation","title":"AutoSysimages.start","text":"start()\n\nStarts AutoSysimages package. It's usually called by start.jl file; but it can be called manually as well.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.latest_sysimage","page":"API Documentation","title":"AutoSysimages.latest_sysimage","text":"latest_sysimage()\n\nReturn the path to the latest system image produced by AutoSysimages, or nothing if no such image exits.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.julia_args","page":"API Documentation","title":"AutoSysimages.julia_args","text":"julia_args()\n\nGet Julia arguments for running AutoSysimages:\n\n\"-J [sysimage]\" - sets the latest_sysimage(), if it exits,\n\"-L [@__DIR__]/start.jl\" - starts AutoSysimages automatically.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.build_sysimage","page":"API Documentation","title":"AutoSysimages.build_sysimage","text":"build_sysimage(background::Bool = false)\n\nBuild new system image (in background) for the current project including snooped precompiles.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.remove_old_sysimages","page":"API Documentation","title":"AutoSysimages.remove_old_sysimages","text":"remove_old_sysimages()\n\nRemove old sysimages for the current project (active_dir()).\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.packages_to_include","page":"API Documentation","title":"AutoSysimages.packages_to_include","text":"packages_to_include()::Set{String}\n\nGet list of packages to be included into sysimage. It is determined based on \"include\" or \"exclude\" options save by Preferences.jl  in LocalPreferences.toml file next to the currently-active project. Notice dev packages are excluded unless they are in include list.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.select_packages","page":"API Documentation","title":"AutoSysimages.select_packages","text":"select_packages()\n\nAsk the user to choose which packages to include into the sysimage.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.status","page":"API Documentation","title":"AutoSysimages.status","text":"status()\n\nPrint list of packages to be included into sysimage determined by packages_to_include.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.add","page":"API Documentation","title":"AutoSysimages.add","text":"add(package::String)\n\nSet package to be included into the system image.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.remove","page":"API Documentation","title":"AutoSysimages.remove","text":"remove(package::String)\n\nSet package to be excluded into the system image.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.active_dir","page":"API Documentation","title":"AutoSysimages.active_dir","text":"active_dir()\n\nGet directory where the sysimage and precompiles are stored for the current project. The directory is created if it doesn't exist yet.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.preferences_path","page":"API Documentation","title":"AutoSysimages.preferences_path","text":"preferences_path()\n\nGet the file with preferences for the active project (active_dir()). Preferences are stored in SysimagePreferences.toml next to the current Project.toml file.\n\n\n\n\n\n","category":"function"},{"location":"chained/#chained_build","page":"Faster compilation (experimental)","title":"Faster compilation (experimental)","text":"","category":"section"},{"location":"chained/","page":"Faster compilation (experimental)","title":"Faster compilation (experimental)","text":"The process of building the whole monolithic system image (sysimamge) takes several minutes. However, most of the functions are already compiled into the binary code in the original sysimage shipped with Julia. It seems possible to compile only newly introduced function and user-specific precompile statements that speed-up the building process significantly. Be aware this chained compilation is very experimental.","category":"page"},{"location":"chained/#**Warning-very-experimental**","page":"Faster compilation (experimental)","title":"Warning very experimental","text":"","category":"section"},{"location":"chained/","page":"Faster compilation (experimental)","title":"Faster compilation (experimental)","text":"The chained sysimage build is currently expected to work only on Ubuntu operation system.","category":"page"},{"location":"chained/","page":"Faster compilation (experimental)","title":"Faster compilation (experimental)","text":"You can try that by compiling branch petvana:pv/fastsysimg from source.","category":"page"},{"location":"chained/","page":"Faster compilation (experimental)","title":"Faster compilation (experimental)","text":"For more details, please read this PR #46045.","category":"page"},{"location":"chained/#How-to-test-chained-sysimages","page":"Faster compilation (experimental)","title":"How to test chained sysimages","text":"","category":"section"},{"location":"chained/","page":"Faster compilation (experimental)","title":"Faster compilation (experimental)","text":"On Ubuntu, you can modify scripts/linux/asysimg script in ~/.local/bin/asysimg by including path to the directory where you compiled the branch.","category":"page"},{"location":"chained/","page":"Faster compilation (experimental)","title":"Faster compilation (experimental)","text":"#!/usr/bin/env bash\nJULIA_EXE=[INSERT-YOUR-PATH-TO-petvana:pv/fastsysimg-BRANCH]/julia\nasysimg_args=`$JULIA_EXE -e \"using AutoSysimages; print(julia_args()); exit();\"`\n$JULIA_EXE $asysimg_args \"$@\"","category":"page"},{"location":"install/#Installation-and-usage","page":"Installation and usage","title":"Installation and usage","text":"","category":"section"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"You can easily install the package using the standard packaging system:","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"] add AutoSysimages","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"The easiest way to use this package is to insert a small script somewhere into your path depending on your operation system.","category":"page"},{"location":"install/#Script-for-Linux","page":"Installation and usage","title":"Script for Linux","text":"","category":"section"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"On Linux, you can use the following bash script that is provided in scripts/linux/asysimg. The recommended location is ~/.local/bin/asysimg.","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"#!/usr/bin/env bash\nJULIA_EXE=julia     # or [INSERT-YOUR-PATH]/julia\nasysimg_args=`$JULIA_EXE -e \"using AutoSysimages; print(julia_args()); exit();\"`\n$JULIA_EXE $asysimg_args \"$@\"","category":"page"},{"location":"install/#Script-for-Windows","page":"Installation and usage","title":"Script for Windows","text":"","category":"section"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"On Windows, you can use the following batch script that is provided in scripts/windows/asysimg.bat. It's recomended add Julia to PATH during installation, and but asysimg.bat into the binary file (e.g., \"C:\\\\Users\\\\xxx\\\\AppData\\\\Local\\\\Programs\\\\Julia-1.X.X\\\\bin\").","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"@echo off\nfor /f \"tokens=1-4\" %%i in ('julia.exe -e \"using AutoSysimages; print(julia_args()); exit()\"') do set A=%%i %%j %%k %%l \n@\"%~dp0\\julia.exe\" %A% %*","category":"page"},{"location":"install/#Basic-usage","page":"Installation and usage","title":"Basic usage","text":"","category":"section"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"Once you install the package and save the script, you can easily run Julia from terminal, using one of the following options with any additional arguments, as normal. It automatically loads the latest system image for your project and start snooping for new precompile statements.","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"asysimg","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"asysimg --project","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"asysimg --project=examples/ExampleWithPlots","category":"page"},{"location":"install/#How-it-works?","page":"Installation and usage","title":"How it works?","text":"","category":"section"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"In the first step, asysimg script detect if there exists a system image for the current project by calling julia_args() and print argument for Julia to load such image. Example of the produced arguments.","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"The first argument (-J) loads the latest system image and is present only if such an image is found. ","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"-J /home/user/.julia/asysimg/1.X.X/4KnVCS/asysimg-2022-09-01T14:54:50.395.so","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"where 4KnVCS is a hash of the project path.","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"The second arguments (-L []/src/start.jl) initializes this package and start snooping for new precompiles statements.","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"-L [AutoSysimages-DIR]/src/start.jl","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"Once the snooping is started it records precompile statements into a temporary files. When the Julia session is terminate, these statements are copied to project-specific file, like","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"/home/user/.julia/asysimg/1.X.X/4KnVCS/snoop-file.jl","category":"page"},{"location":"install/#Select-packages","page":"Installation and usage","title":"Select packages","text":"","category":"section"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"You can select packages to be included into the project-specific system images. There is an interactive selection process that can be triggered by calling","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"using AutoSysimages\nselect_packages()","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"That shows the manual selection (asysimg --project=examples/ExampleWithPlots/)","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"asysimg> select_packages()\n[ Info: Please select packages to be included into sysimage:\n[press: Enter=toggle, a=all, n=none, d=done, q=abort]\n > [ ] LinearAlgebra\n   [ ] OhMyREPL\n   [X] Plots\n   [ ] Printf","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"The settings are stored in SysimagePreferences.tomlfile just next to the current Project.toml file. You can modify the settings manually in the file.","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"[AutoSysimages]\ninclude = [\"Plots\"]\nexclude = []","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"To check which versions of the packages will be included, you can run","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"asysimg> status()\n    Project `/home/petr/repos/AutoSysimages/examples/ExampleWithPlots/Project.toml`\n   Settings `/home/petr/repos/AutoSysimages/examples/ExampleWithPlots/SysimagePreferences.toml`\nPackages to be included into sysimage:\n  [91a5bcdd] Plots v1.31.7","category":"page"},{"location":"install/#(Re)build-sysimage","page":"Installation and usage","title":"(Re)build sysimage","text":"","category":"section"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"You can rebuild your system image at any time, but the changes will be reflected only after you restart Julia (using asysimg). It automatically includes all the selected packages and recorded precompile statements.","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"using AutoSysimages\nbuild_sysimage()","category":"page"},{"location":"install/","page":"Installation and usage","title":"Installation and usage","text":"The sysimage will be generated by PackageCompiler, or by very experimental chained builds.","category":"page"},{"location":"#About","page":"About","title":"About","text":"","category":"section"},{"location":"","page":"About","title":"About","text":"This package automates building of user-specific system images (sysimages) for the specific project.  ","category":"page"},{"location":"#Main-features","page":"About","title":"Main features","text":"","category":"section"},{"location":"","page":"About","title":"About","text":"Automatically stores precompile statements for the given project.\nSingle command build process by build_sysimage().\nRemoves old unused sysimages.\nWarns if the loaded sysimage contains outdated packages (Julia v1.8+).","category":"page"},{"location":"#Possible-future-features","page":"About","title":"Possible future features","text":"","category":"section"},{"location":"","page":"About","title":"About","text":"Automatic building in background process\nDetailed statistics about compiled functions\nProper support for fast building of package or system images","category":"page"},{"location":"#Basic-example-with-Plots","page":"About","title":"Basic example with Plots","text":"","category":"section"},{"location":"","page":"About","title":"About","text":"(Image: asciicast)","category":"page"}]
}
