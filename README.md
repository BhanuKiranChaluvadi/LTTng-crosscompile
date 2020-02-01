# LTTng-crosscompile
Simple bash script to cross compile LTTng UST and Tools


This is mostly copied from stack overflow replies https://stackoverflow.com/questions/13774455/how-do-i-build-and-deploy-lttng-to-an-embedded-linux-system. Thanks to @crazyfury.

The bash script is tailored to my current needs. 
Instead of compiling LTTng's urcu,ust,tools from latest git repo's, tar files with specific version is chosen. 
Tar files are chosen to have a control over the cross-compiled version and to avoid autoconf(./bootstrap), which is creating some issue on my current system.


# RUN
1. git clone 
2. sudo ./lttng_crosscompile.bash
