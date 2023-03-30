# Introduction

This is a description of how I handle cross-compilation for Linux (i686, x86_64, aarch64, armv6 and armv7, sparc, linux, mips, powerpc), FreeBSD, Solaris, MacOS and to a lower extent, Windows. There is also a section on how I have structured my repositories and decided of source vs pre-compiled.

# Compilation

Because my applications have some so many binary versions, I need a centralized compilation system. I can't have a VM for each target or even a Docker instance. I need a solid, scriptable set of cross-compilers.

## Linux

This was supposed to be the easy part. I'm under some Debian-based distro and moved to 22.04 LTS at the time of this writing. A lot of compilers are provided pre-built and can be added with:
```
 sudo apt-get install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
 sudo apt-get install gcc-arm-linux-gnueabi binutils-arm-linux-gnueabi
 sudo apt-get install gcc-sparc64-linux-gnu binutils-sparc64-linux-gnu
 sudo apt-get install gcc-mips-linux-gnu binutils-mips-linux-gnu
 sudo apt-get install gcc-powerpc-linux-gnu binutils-powerpc-linux-gnu
```
But a first issue starts when compiling for 32 and 64 bits Intel *and* these other architectures. Normally, the default Intel compiler is multi-lib, which means that it's 64 bits by default and by adding `sudo apt-get install gcc-multilib` (from memory, actual syntax might be a bit different) then you are good to go to produce 32 bits versions when compiled with '-m32' flags.

Well, unfortunately, there is an ancient incompatibility with all other compilers that nobody dared to fix which means that as soon as you install one of the other ones named above, the multilib x86 option is removed. You have to install separately an i686 compiler, which fortunately is also an available package
```
 sudo apt-get install gcc-i686-linux-gnu binutils-i686-linux-gnu
```
Note that you'll lose the ability to use '-m32' and some packages relying on that might fail. You’ll have to patch them then.

With that you have a lot of Linux compilers available. This sounds all good and if your intention is to use what you compile for your own machine (and forward in time), you are good to go.

Unfortunately, as soon as you want to distribute the compiled binaries to other machines, then you'll face GLIBC versioning nightmare. Indeed, GLIBC uses something named symbol versioning which means that when you link your application with the dynamic loader libs, they tell what is the minimum version of GLIBC symbols that they accept at runtime when they will load. These versions are based on the machine you have built with, so chances are that on a 22.04 distro, you'll need something around and above GLIB 2.35 and nothing below will work, you’ll end up with your apps refusing to run saying ‘glibc 2.35 is missing’ (or something similar).

There has been a lot of debate about how this is handled in Linux and I personally don't like it, as the only compatibility you can have is for future versions, but nothing can go backward – you can NOT build for older systems on a recent machine. AFAIK, MacOS and Windows do that very easily. 

The idea to decide what GLIBC version at compile time with your built-in compilers does not work, and I've tried that (very hard). In addition, you'll have issues with stdlibc++ which has a similar but worse version of that problem. It is linked to gcc version, see [here](https://gcc.gnu.org/onlinedocs/libstdc++/manual/abi.html)

The usual answer you find is "you idiot, just use an old machine to build". I find this well-spread advice really silly as I want to build on a recent machine, obviously, because I need recent tools as well! That makes no sense to say that devs should use outdated distributions.

After many attempts, the only scalable solution I've found is to rebuild *all* the compilers, for your native CPU but also all cross-compilers. This sounds awful, but there is a very fine solution named [crosstools-ng](https://crosstool-ng.github.io/). It can look a bit intimidating at the beginning but it's not, especially if you use listed samples. 

In this repository, I've added a list of '.config.stretch.xxx' files that are my own verified configuration for ct-ng based on Debian Stretch (means around early 2016) and they all use a glibc version 2.23 and kernel 4.4+. This gives enough mileage, IMHO with 6-years old type of distros.

If these GLIBC and GLIBCXX are still too new for your system, you're not yet out of luck, you can try to force your application to use the libc and libstdc++ that you have just built with the compilers. See [below](#running-an-application-by-forcing-glibc-and-glibcxx) for more explanations.

Now, that might not always work so in last resort you can build 'static' versions of your apps using the '-static' linker flag. Understand that although this works, quite often, this is a bad idea as the result is not a more portable, independent, solution, but it's a much bigger binary that will not benefit from future dynamically loaded libraries fixes (think issues with openssl for example) and even worse won't be fully independent because if your application uses dlopen (e.g.) it will still try to load libraries and in that case it will work on if runs with the exact glibc it has been built with. So ‘-static’ is really a last resort option, despite what some say.

Now, when you rebuild glibc, you can configure it with '--enable-static-nss' and at least `gethostname` and `getaddrinfo` won't try to use dlopen so they won't require the GLIBC you've compiled with (it has other implication in term of name resolving but you can Google that). There might be other limitations that I'm not aware of. All my ct-ng examples include this option.

I usually install my compilers on path like `/opt/<cpu>-<os>` and add these `<path>/bin` to an `/etc/profile.d/xxx.sh` file so that the $PATH let me access all my compilers (just add `export PATH=$PATH:<path>` in that .sh file)

NB: In ct-ng 12.25.0, there is an issue with the zlib used (not found), so you need to manually edit the generated .config and replace the version which ends in .12 by .13. There is another problem with mips if you want to use glibc 2.23. You need to grab the latest patch file `0014-MIPS-SPARC-fix-wrong-vfork-aliases-in-libpthread.so` (see [here](https://github.com/crosstool-ng/crosstool-ng/pull/1746)).

# FreeBSD and Solaris

There is no fully automated solution AFAIK, but it's reasonably easy to create compilers for these. Install a version of the OS in a VM or find a solution to get the /usr/lib (and /usr/lib32 for freeBSD), usr/include, and /lib directories. These can be pretty large and it's more than what you really need, so try to minimize it by starting from a fresh installation. I'm not even sure that /lib is needed but I took it anyway. 

You should ‘tar’ these from the source machine and ‘untar’ on the machine where you want the cross-compiler to run (see below where). For similar reasons described in Linux, you have to be careful about the version of the OS you take the include and lib from, as it can limit how backward compatible you are. 

Then you need to get, from [gnu sources](https://www.gnu.org/software/) different packages: binutils, mpc, gmp, mpfr, libtool and finally gcc itself. You can choose any version, as long as they form a consistent package. You'll find in this repository a couple of "scripts" that automate the build for you. Please take them with a grain of salt as they are not well-behaving scripts, just quick hacks, so read them carefully before using them.

No matter what you do, there are a few important considerations. You'll find at the beginning of these scripts, the following
```
export TARGET=x86_64-cross-freebsd$1
export PREFIX=/opt/x86_64-freebsd$1/
export SYSROOT=$PREFIX$TARGET/
export PATH=$PATH:$PREFIX/bin
```
And these are the most important things when building these cross-compilers. 

`$TARGET` defines the base name of the compiler itself and is also used by the configuration and makefiles provided by gnu to figure out what target you want to build for. In the example above, compiler components will be named (assuming the script is invoked with '13.1) 'x86_64-cross-freebsd13.1-gcc|ld|ar|ranlib'. You can’t choose anything you want otherwise builds will fail, as they won’t be able to figure out the targeted cpu.

`$PREFIX` defines where these will be installed and where they expect to run from, precisely under $PREFIX and $PREFIX$TARGET (as $PREFIX ends with a '/').

`$SYSROOT` is a very important item as well as it defines where the new compiler will find it's includes and libs. You don't want it to search the /usr/lib of the machine used to build and you don't want to have to set 'sysroot' every time you invoke the cross-compiler, so it's much better to set it when you build the compiler. That will point for where you ‘untar’ what you got from the source machine. Read the gnu docs here, there are some subtilities, for example like if sysroot is made of $PREFIX and $TARGET when you build the compiler, then it will be built with **relative** path to where it runs, which can be very convenient if you want to move it to another place later. Otherwise, the path to its /usr/lib, /usr/include will be hardcoded.

Finally, when building gcc itself, you must have your `PATH` giving access to binutils build before, otherwise build will fail.

Note that the untar directory of the targets’ /usr/lib[32], /usr/include and /lib is `$PREFIX$TARGET`. Some other guides don't do that but then they have to correct all the symlinks that are defined in the directories of the machine where you borrowed them. I find that useless and prefer to have a clean ‘tar/untar’, with all symlinks ready to be untar at the right place (BTW, this is why you want to use ‘tar’, not ‘cp’ to make sure these symlinks are preserved). 

Have a look as well at the command line of the configure of each item, and you'll see where and why $SYSROOT is set. Again, these are *very* important settings. Read the gnu manual or the configure scripts carefully before changing them.

Once you have that done, you can run a version of this script matched to what you prefer and then it will install in ‘/opt’, *providing the user doing the build has rw access*. 

I’ve used recently Solaris 11.4 and FreeBSD 12.3 and 13.1 with gcc 12.2 and all lasted other packages and it build and run well.

NB: There is something strange with the Solaris build that I've not investigated which forces me to run it as root for now. Don't forget that when you 'sudo' something, the $PATH is not the one of the sudo issuer, it's a "safe" version so you need to do `sudo env PATH=$PATH <command>` if you want to use your current $PATH.

NB: The solaris version is set to 2.x although solaris lates version is 11.4. Leave it like that because the gnu configuration scripts require a ‘solaris2…’ version to recognize the target. I guess nobody dared to update them.

## MacOS

The situation is a bit better with MacOS thanks to [osxcross](https://github.com/tpoechtrager/osxcross). There is not much to add, just carefully read the instructions that I won't duplicate here.
 
There is only one caveat if you build on folders that are not local, I've found an issue in the libtool provided and I've submitted a PR [here](https://github.com/tpoechtrager/cctools-port/pull/126). Similarly, when you use clang compiler, it will leave a ton of ".tmp" files behind unless you use compile flag`-fno-temp-file`.

On the osxcross guide, note that you can build gcc as well, which is what I'm using. The arm64 compiler works for me, but it has to be **arm64**, not **arm64e**. Note that lipo also allows universal binaries to be built, although the tool is pretty inconvenient in its replace/update options.

## Windows

A few words on Windows as well. There, I use mainly Visual Studio and projects/solutions. Nevertheless, it is worth mentioning that most of the packages that come with CMake build files can automatically generate VS projects. Just do, on your Windows machine, as you do on a Linux box `Cmake .. -A Win32 <options>` (or maybe another option, look at each README) and it will mostly magically spit out '.vcxproj' files that you can use later. This is what I do in my "pre-compiled builds" described below.

# Organizing submodules & packages 
Most of my applications have been through increasing complexity in term of number of platform (Windows, Linux x86, x86_64, arm, aarch64, sparc, mips, powerpc, OSX, FreeBSD, Solaris) and amount of used modules/3rd party repositories. This led to complicated builds, especially because I want to do automated cross-compilation. 

I’ve decided to pre-build some of the packages I use, whether they are mine or 3rd parties'. These packages do not evolve fast and having them available in binary saves a lot of compiling time and (re)building complexity about details like setting the right flags in each project, especially if you don’t have proper build tool provided by the maintainer. 

I know this is a domain of strong opinions and many would say “use CMake and rebuild all from source”, I just think CMake is over-complicated for some of what I do and more important, it’s not always available. Some libraries (openssl) use a Perl script, some only provide autotools, some do CMake and autotools…

So I’ve adopted a sort of interim approach where you can rebuild all what I provide, but you can also choose to use pre-build binaries for each sub-modules/packages and only rebuild the core of the application. Every package I use is organized the following way:
```
-- <various sources and other stuff needed for the package>
-- build.sh
-- build.cmd
-- <package-name>Config.cmake (optional)
-- targets
   |-- include/<sub-package>/*.h
   |-- <os>/include/<sub-package>/*.h
   |-- <os>/<cpu>/include/<sub-package>/*.h
   |-- <os>/<cpu>/*.a|*.lib|*.la|*.so|*.dll
```
\<os\> => win32, linux, mac, freebsd, solaris
\<cpu\> => x86, x86_64, arm, aarch64, sparc64, mips, powerc

The '<package-name>Config.cmake is an optional package finder for cmake. It allows the libraries to be found using find_package(<package-name> CONFIG [PATH <path>]). The attached example will populate properties that can be retrieved using some properties - it requires variables HOST (os) and PLATFORM (cpu) to be defined and to match the structure above
 ```
 get_target_property(<MyVAR> <package-name>::<library> INTERFACE_INCLUDE_DIRECTORIES)
 get_target_property(<MyVAR> <package-name>::<library> IMPORTED_LOCATION_RELEASE}
 ```
The ‘include’ directory in ‘targets’ only exists if the package is clean enough to have an API that works for every cpu and os. Similarly, an ‘include’ might work at the os level, regardless of cpu. In case there is no rule, then 'include' exists under each <os>/<cpu> directory.

In root, a set of build scripts or .vcxproj can be found to rebuild these libraries if needed, but the goal is to not have to. It will be ‘build.cmd’ for Windows and ‘build.sh’ for all others.

In the <os>/<cpu> directory, there are all the libraries (mostly static) that are offered by the package and a library (named after the package) that is the concatenation of all these so that the application consuming it does not need to know individual names (you need to know what to include, though). 

For example, ‘openssl’ offers ‘libcrypto’ and ‘libopenssl’. I don’t want to have to explicitly refer to these when I build my applications, so they are concatenated into a single ‘libopenssl.a’. I've not put all the .h in the same directory when a package aggregates multiple sub-packages. This means that your app's makefile must set each individual sub-package directory and that's a bit painful, but putting them alltogether has other namespace collision risks (some packages want you to include `<package>/<dir>`to avoid namespace issues that would arise otherwise anyway during headers search)

Note that all the individual libraries are still there and the concatenated one is (when possible) just a “thin” library.

There are two types of repositories: local and proxy.

## Local packages
These repositories contain only code that I provide and that I’ve decided to build as binaries because it does not change often and does not need to be tailored to the application being build (no compile flags needed by the app).

Not all my repositories can be like that, for example [crosstools]( https://github.com/philippe44/crosstools) is used as source code directly because the final application might tweak some flags that are not os or cpu related

## Proxy packages
Proxy repositories mainly consume other module(s) in the form of sub-module(s). They might have some code of their own to provide addons (usually in the format of an ‘addons’ directory), but most of the time they are simply referring to the upstream module(s) they proxy (which can be mine or a 3rd party) and then have the ‘targets’ structure where they provide the binary versions.

Good example of that is the [libcodecs](https://github.com/philippe44/libcodecs) package that includes many codecs from upstream directly when possible and from my forks when needed.

## Cloning and rebuilding
The ‘build.sh’ script is a cross-compiling script (for non-Windows) that will rebuild all the targets it can, depending on the compilers existing on your machine. Please have a look at the script, it’s very simple and you can adjust it if needed in case compilers names don’t match. It can be invoked with the following syntax:
```
./build.sh [clean] [<compiler_1> .. <compiler_n>]
```
Where \<compiler\> is a string that matches the compilers you want to use (for example 'x86' will match all os and cpu that include 'x86' in their name) and 'clean' performs some cleanup. Note that 'clean' sometimes means just do a cleanup and you'll ahve to invoke the script again to build, sometimes it means 'clean and build'.

Inside the scripts, the ‘list’ variable list compiler names which sets the \<os\> and <\cpu\> names and the ‘alias’ variable is an indirection to the **real** compiler, as they might not be the same. 

For example, I prefer to have 32 bits Intel binaries named by ‘x86’ so the 'list' name is ‘x86-linux-gnu-gcc’ which is not a real compiler but the 'alias' tells it is ‘i686-linux-gnu-gcc’. It’s very convenient if the same compiler can produce two types of binaries, depending on some flags. The names used in 'list' are also used to set the target OS and CPU automatically, hence they have comply strictly to a naming convention, when the alias does not have to.

For Windows, use build.cmd for Windows (needs Visual Studio). The only parameter is 'rebuild' which mean a full cleanup and potentially running CMake's reconfigure.

When you clone one of these repositories, you can just do a normal clone in which case you have the ‘targets’ directory with all includes and libraries which should be enough to use and rebuild it.

Now, when a package refers to sub-modules (and all proxy ones do), then these are needed if you want to rebuild it (once again, this is not needed nor is it the objective, but it’s possible). In such a case do a `git clone \<repository\> [\<directory\>] -–recursive` to get everything and be able to rebuild.

## Application recommendation wrt recursive cloning
My applications (for example [AirConnect]( https://github.com/philippe44/AirConnect)) leverage that system a lot and if you decide to clone it recursively, it will pull a ton of sub-modules, because one of the package it is using can also need many sub-modules, sometimes the sames are required multiple times.

That’s why cloning recursively such repositories is not a good idea. If you want to rebuild; I recommend doing a 2-steps cloning.

1-	Clone the main repository: `git clone https://github.com/philippe44/AirConnect`
2-	Init its submodules non-recursively: go into “AirConnect” and then do a `git submodule update -–init`
This will do a ‘one level only’ cloning which is sufficient to build the main application and rebuild all its sub-modules/packages.

# Running an application by forcing GLIBC and GLIBCXX
If the OS you're trying to run an application onto has GLIBC or GLIBCXX that are too old, you can force the dynamic library loader to look first into specific directories where you'd have put your version of these libraries. 

You have to find the libraries built with your compiler (I have uploaded some [here](https://github.com/philippe44/cross-compiling/blob/master/GLIB.xz)). There will be a libc.so.x and a libstdc++.x.y.z files, probably one in lib/ and one in lib/amd64 (or lib64 or similar). Copy them on your target system under typically /usr/local/lib and creates symlinks so that these new libs mirror a normal libc/libstdc++ setup. For this, look at other symlinks for the pre-installed libc and libcstdc++ under /lib to figure out exactly what you need to do and don't forget to chmod all these files so that anybody can read them.

Then, you can run the application simply using
```
LD_LIBRARY_PATH=/usr/local/lib <application>
```
You can also use system variables. For example, this forces the search to be made below the directory **containing** the application and use either "lib" or "lib64" (or whatever your loader expects).
```
LD_LIBRARY_PATH='$ORIGIN/$LIB' <application>
```
You can also set LD_LIBRARY_PATH system-wide (using export LD_LIBRARY_PATH=\<...\>) but I really don't recommand doing that. Similarly, I totally discourage overwriting the system libc and libstdc++ system-side - this is looking for troubles, really!
 
You can also try setting LD_NOVERSION=1 to avoid anycheck, at your own peril

Here is an untested script example for Solaris
```
library=libstdc++.so.6.0.29

mkdir amd64
ln -s . 32
ln -s amd64 64

pwd = $(pwd)

cd 32
ln -s $library libstdc++.so 
ln -s $library libstdc++.so.6
cd $pwd

cd 64
ln -s $library libstdc++.so 
ln -s $library libstdc++.so.6
cd $pwd

chmod -R o+r libstdc++*
```


