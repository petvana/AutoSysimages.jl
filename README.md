# AutoSysimages.jl
Automate user-specific system images for Julia

> **Warning**
> This package uses chained sysimage build that is not yet supported by Julia. You can try that by compiling branch [petvana:pv/fastsysimg](https://github.com/petvana/julia/tree/pv/fastsysimg) from source.

## Ho to install

After you install the package to the Julia, you need to include (or symlink) script `jusim` into the system path. Currently you also need to update Julia's path to where [petvana:pv/fastsysimg](https://github.com/petvana/julia/tree/pv/fastsysimg) is compiled.


Then you can run the `jusim` script providied by the package
``` bash
#!/usr/bin/env bash

# Runs julia with user-specific system images.
# This is part of AutoSysimages.jl package
# https://github.com/petvana/AutoSysimages.jl

JULIA_EXE=[INSERT-YOUR-PATH]/julia

julia_cmd=`$JULIA_EXE -e "using AutoSysimages; print(AutoSysimages.get_autosysimage_args()); exit(0);"`
$JULIA_EXE $julia_cmd "$@"

```

Once in a while, it is recomended to run
```
AutoSysimages.build_system_image()
```
to rebuild the system image.