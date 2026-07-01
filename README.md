# Quoil

Quoil is a desktop shell configuration using Quickshell for NixOS. It is a fork of the Caelestia Shell by Soramane. Currently there are almost no differences in this fork, but over time I will be customizing it for efficiency and usefulness for me and my specific workflow. Example changes (there will be plenty more), are moving the task bar to the top of the screen, more reactive audio visualizer, embedded timer, screenshotter, alarms, etc.


NOTE: Currently the way to use this shell is to clone the repo, and build the dependancies:

To build and run:

> \# From inside the quoil directory:<br>
> `nix develop`   # drops you into a shell with Qt6, cmake, clang, etc.
>
> \# Inside that shell — only need to do this once (or after C++ changes): <br>
> `cmake -B build && cmake --build build -j$(nproc)`
>
> \# Exit the dev shell, then run the shell any time: <br>
> `./run-quoil.sh`

Also, the truth is that running run-quoil.sh might actually build everything automatically anyway. You can try and just run ./run-quoil.sh first if you want lol.