# https://gcc.gnu.org/install/configure.html
# https://acg.cis.upenn.edu/milom/cross-compile.html

# THAT SCRIPT MUST BE RUN AS ROOT FOR A REASON I DON't UNDERSTAND OTHERWISE
# GCC WILL NOT BUILD. MAYBE A PATH ISSUE (PATH WHEN ROOT IS "SAFE")?

# we have to fake version as binutils does no support above 2.x
export TARGET=x86_64-cross-solaris2.x
# need a trailing '/'
export PREFIX=/opt/x86_64-solaris2.x/
export SYSROOT=$PREFIX$TARGET/
export PATH=$PREFIX/bin:$PATH

mkdir -p $PREFIX/$TARGET
tar xvf solaris11.4.tgz --directory $PREFIX/$TARGET

# https://ftp.gnu.org/gnu/binutils/binutils-2.39.tar.xz
item=binutils-2.40
rm -rf $item
tar xvf $item.tar.xz 
pushd $item
./configure --enable-libssp --enable-ld --target=$TARGET --prefix=$PREFIX --with-sysroot=$SYSROOT
make -j16 && make install
popd

# https://gmplib.org/download/gmp/gmp-6.2.1.tar.xz
item=gmp-6.2.1 
rm -rf $item
tar xvf $item.tar.xz 
pushd $item
./configure --prefix=$PREFIX --enable-shared --enable-static --enable-mpbsd --enable-fft --enable-cxx --host=$TARGET
make -j16 && make install
popd

# https://www.mpfr.org/mpfr-current/mpfr-4.1.0.tar.xz
item=mpfr-4.1.0
rm -rf $item
tar xvf $item.tar.xz 
pushd $item
./configure --prefix=$PREFIX --with-gnu-ld  --enable-static --enable-shared --with-gmp=$PREFIX --host=$TARGET
make -j16 && make install
popd

# https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz
item=mpc-1.2.1
rm -rf $item
tar xvf $item.tar.gz 
pushd $item
./configure --prefix=$PREFIX --with-gnu-ld --enable-static --enable-shared --with-gmp=$PREFIX --with-mpfr=$PREFIX --host=$TARGET
make -j16 && make install
popd

# https://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz
item=libtool-2.4.6
rm -rf $item
tar xvf $item.tar.gz
pushd $item
./configure --prefix=$PREFIX --enable-static --enable-shared --host=$TARGET --with-sysroot=$SYSROOT --program-prefix=$TARGET-
make -j16 && make install
popd

# gcc
# the build-sysroot must be set because the sysroot is a subpath of prefix. In that case, the 
# configure script makes is relative to where gcc is, so that it's relocatable. Unfortunately, 
# that works for USING the compiler, but not for BUILDING it (during this phase below)
item=gcc-11.2.0
rm -rf $item
tar xvf $item.tar.xz 
pushd $item
mkdir -p build && cd build
../configure --without-headers --with-gnu-as --with-gnu-ld --disable-nls --enable-languages=c,c++ --enable-libssp --enable-ld --disable-libitm --disable-libquadmath --target=$TARGET --prefix=$PREFIX --with-gmp=$PREFIX --with-mpc=$PREFIX --with-mpfr=$PREFIX --disable-libgomp --with-sysroot=$SYSROOT --with-build-sysroot=$SYSROOT
make -j16 && make install
popd

exit
