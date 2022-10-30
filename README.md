# Introduction

This is a description of how I handle cross-compilation for Linux (i686, x86_64, sparc, linux, mips, powerpc), FreeBSD, Solaris, MacOS and to a lower extent, Windows. There is also a section on how I structured y repositories and decide of source vs pre-compiled.

# Compilation

Because my applications exist with so many different binaries, I need a centralized compilation system. I can't have VM for each target or even a Docker instance. I need a solid, scriptable set of cross-compilers.

## Linux

This was supposed to be the easy part. I'm under some Debian-based distro and moved to 22.04 LTS at the time of this writing. A lot of compilers are provided pre-build and can be added with:
`
 sudo apt-get install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
 sudo apt-get install gcc-arm-linux-gnueabi binutils-arm-linux-gnueabi
 sudo apt-get install gcc-sparc64-linux-gnu binutils-sparc64-linux-gnu
 sudo apt-get install gcc-mips-linux-gnu binutils-mips-linux-gnu
 sudo apt-get install gcc-powerpc-linux-gnu binutils-powerpc-linux-gnu
` 
But a first issue starts when compiling for 32 and 64 bits Intel *and* these other architecture. Normally, the default intel compiler is multi-lib, which means that it's 64 bits by default and by adding `sudo apt-get install gcc-multilib` (from memory, actual syntax might a bit different) then you are good to go to provide 32 bits files when compiled with '-m32' flags.

Well, unfortunately, there is an ancient incompatibility with all other compilers that nobody dared to fix which means that as soon as you install one of the other ones named above, the multilib x86 option is removed. You have to install separately an i686 compiler, which fortunately is also an available package
`
 sudo apt-get install gcc-i686-linux-gnu binutils-i686-linux-gnu
` 
Not that you'll lose the ability to use '-m32' and some packages relying on that might fail. You’ll have to patch them then.

With that you have a lot of Linux compilers available. This sounds all good and if your intention is to use what you compile for your own machine (and forward in time), you are good to go.

Unfortunately, as soon as you want to distribute the compiled binaries to other machines, then you'll face GIBC versioning nightmare. Indeed, GLIBC uses something named symbol versioning which means that when you link your application with the dynamic loader libs, they tell what is the minimum version of GLIBC symbols that they accept at runtime when they will load. These versions are based on the machine you are built with, so chances are that on a 22.04 dstro, you'll need something around GLIB 2.35 and nothing below will work, you’ll end up with your apps refusing to run saying ‘glibc 2.35 is missing’ (or something similar).

There has been a lot of debate about how this is handled in Linux and I personally don't like it, as the only compatibility you can have is for future versions, but nothing can go backward – you can NOT build for older systems on a recne tmachine. AFAIK, MacOS and Windows allow that very easily. 

The idea to GLIBC version at compile time with your built-in compilers does not work, and I've tried that (very hard). In addition, you'll have issues with stdlibc++ which has a similar but worse version of that problem. 

The usual answer you find is "you idiot, just use an old machine to build". I find this well-spread advice really bad as I want to build on a recent machine, obviously, because I need recent tools as well!

After many attempts, the only scalable solution I've found is to rebuild *all* the compilers, for your native CPU but also all cross-compilers. This sounds awful, but there is very fine solution using [crosstools-ng](https://crosstool-ng.github.io/). It can look a bit intimidating at the beginning but it's not, especially if you use listed samples. 

In this repository, I've added a list of '.config.stretch.xxx' files that are my own verified configuration for ct-ng based on Debian Stretch (means around early 2016) and they all use a glibc version 2.23. This gives enough mileage, IMHO with 6-years old type of distros.

Now, that might not always work so in last resort you can build 'static' versions of your apps using the '-static' flag. Understand that although this works, quite often, this is a bad idea as the result is not a more portable, independent, solution, but it's a much bigger binary that will not benefit from future dynamically loaded corrections (think issues with openssl for example) and even worse won't be fully independent because if your application uses dlopen (e.g.) it will still try to load libraries and in that case it will work on if runs with the exact glibc it has been built with. So ‘-static’ is really a last resort option, despite what some say.

I usually install my compilers on path like /opt/<cpu>-<os> and add these <path>/bin to an /etc/profile.d/xxx.sh file so that the $PATH let me access all my compilers (just add `export PATH=$PATH:<path>` in that .sh file)

NB: in ct-ng 12.25.0, there is an issue with the zlib used (not found), so you need to manually edit the generated .config and replace the version which ends in .12 by .13. There is another problem with mips if you want to use glibc 2.23. You need to grab the latest patch file `0014-MIPS-SPARC-fix-wrong-vfork-aliases-in-libpthread.so` (see |here](https://github.com/crosstool-ng/crosstool-ng/pull/1746))

# FreeBSD and Solaris

There is no fully automated solution AFAIK, but it's reasonably easy to create compilers for these. Install a version of these in a VM or find a solution to get the /usr/lib (and /usr/lib32 for freeBSD), usr/include, and /lib directories. These can be pretty large and it's more than what you really need, so try to minimize it by starting from a fresh installation. I'm not even user that /lib is needed but I took it anyway. 

You should ‘tar’ these from the source machine and ‘untar’ on the machine where you want the cross-compiler to run (see below where). For similar reasons described in Linux, you have to be careful about the version of the OS you take the include and lib from, as it can limit how backward compatible you are. 

Then you need to get, from [gnu sources](https://www.gnu.org/software/) different packages: binutils, mpc, gmp, mpfr, libtool and finally gcc itself. You can choose any version, as long as they form a consistent package. You'll find in this repository a couple of "scripts" that automate the build for you. Please take them with a grain of salt as they are not well-behaving scripts, just quick hacks, so read them carefully before using them.

No matter what you do, there are a few important considerations. You'll find at the beginning of these scripts, the following
`
export TARGET=x86_64-cross-freebsd$1
export PREFIX=/opt/x86_64-freebsd$1/
export SYSROOT=$PREFIX$TARGET/
export PATH=$PATH:$PREFIX/bin
`
And these are the most important things when building these cross-compilers. 

TARGET defines the base name of the compiler itself and is also used by the configuration and makefiles provided by gnu to figure out what target you want to build for. In the example above, compiler components will be named (assuming the script is invoked with '13.1) 'x86_64-cross-freebsd13.1-gcc|ld|ar|ranlib'. You can’t choose anything otherwise builds will fail, as they won’t be able to figure out the targeted cpu.

PREFIX defines where these will be installed and where they expect to run from, precisely under $PREFIX and $PREFIX$TARGET (as $PREFIX ends with a '/').

SYSROOT is a very important item as well as it defines where the new compiler will find it's includes and libs. You don't want it to search the /usr/lib of the machine used to build and you don't want to have to set 'sysroot' every time you invoke the cross-compiler, so it's much better to set it when you build the compiler. That will point for where you ‘untar’ what you got from the source machine. Read the gnu docs here, there are some subtilities, for example like if sysroot is made of $PREFIX and $TARGET when you build the compiler, then it will be built with **relative** path to where it runs, which can be very convenient if you want to move it to another place later. Otherwise, the path to its /usr/lib, /usr/include will be hardcoded.

Finally, when building, gcc, you must have PATH giving access to binutils build before, otherwise build will fail.

Note that the untar directory of the targets’ /usr/lib[32], /usr/include and /lib is `$PREFIX$TARGET`. Some other guides don't do that but then they have to correct all the symlinks that are defined in the directories of the machine where you borrowed them. I find that useless and prefer to have a clean ‘tar/untar’, with all symlinks ready to be untar at the right place (BTW, this is why you want to use ‘tar’, not ‘cp’ to make sure these symlinks are preserved). 

Have a look as well at the command line of the configure of each item, and you'll see where and why $SYSROOT is set. Again, these are *very* important settings. Read the gnu manual or the configure scripts carefully before changing them.

Once you have that done, you can run a version of this script matched to what you prefer and then it will install in ‘/opt’, *provifing the user doing the build has rw access*. 

I’ve used recently Solaris 11.4 and FreeBSD 12.3 and 13.1 with gcc 12.2 and all lasted other packages and it build and run well.

NB: There is something strange with the solaris build that I've not investigated which forces me to run it as root for now. Don't forget that when you 'sudo' something, the $PATH is not the one of the sudo issuers, it's a "safe" version so you need to do `sudo env PATH=$PATH <command>` if you want to use you current $PATH.

NB: The solaris version is set to 2.x although solaris lates version is 11.4. Leave it like that because the gnu configuration scripts require a ‘solaris2…’ version to recognize the target. I guess nobody dared to update them.

## MacOS

The situation is a bit better with MacOS thanks to [osxcross](https://github.com/tpoechtrager/osxcross). There is not much to add, just carefully read the instructions that I won't duplicate here<
 
There is only one caveat if you build on folders that are not local, I've found an issue in the libtool provided and I've submitted a PR [here](https://github.com/tpoechtrager/cctools-port/pull/126). Similarly, when you use clang compiler, it will leave a ton of ".tmp" files behind unless you use compile flag`-fno-temp-file`.

On the osxcross guide, note that you can build gcc as well, which is what I'm using.

## Windows

A few words on Windows as well. There, I use mainly Visual Studio and projects/solutions. Nevertheless, it is worth mentioning that most of packages that come with CMake build files can automatically generate VS projects. Just do, on your Windows machine, as you do on a Linux box `Cmake .. -A Win32 <options>` and it will mostly magically spit out '.vcxproj' files that you can use later. This is what I do in my "pre-compiled builds" described below.
d it will mostly magically spit out '.vcxproj' files that you can use later? THis is what I do in my "pre-compiled builds" described below.
