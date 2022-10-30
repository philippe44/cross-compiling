# https://gcc.gnu.org/install/configure.html
# https://acg.cis.upenn.edu/milom/cross-compile.html

if [ -z $1 ]; then
	echo please set version
	exit
fi

export TARGET=x86_64-cross-freebsd$1
# need a trailing '/'
export PREFIX=/opt/x86_64-freebsd$1/
export SYSROOT=$PREFIX$TARGET/
export PATH=$PATH:$PREFIX/bin

mkdir -p $PREFIX/$TARGET
tar xvf freebsd.$1.tgz --directory $PREFIX/$TARGET || exit

# https://ftp.gnu.org/gnu/binutils/binutils-2.39.tar.xz
item=binutils-2.39
rm -rf $item
tar xvf $item.tar.xz 
pushd $item
./configure --enable-libssp --enable-ld --target=$TARGET --prefix=$PREFIX --with-sysroot=$SYSROOT
make -j8 && make install
popd

# https://gmplib.org/download/gmp/gmp-6.2.1.tar.xz
item=gmp-6.2.1 
rm -rf $item
tar xvf $item.tar.xz 
pushd $item
./configure --prefix=$PREFIX --enable-shared --enable-static --enable-mpbsd --enable-fft --enable-cxx --host=$TARGET
make -j8 && make install
popd

# https://www.mpfr.org/mpfr-current/mpfr-4.1.0.tar.xz
item=mpfr-4.1.0
rm -rf $item
tar xvf $item.tar.xz 
pushd $item
./configure --prefix=$PREFIX --with-gnu-ld  --enable-static --enable-shared --with-gmp=$PREFIX --host=$TARGET
make -j8 && make install
popd

# https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz
item=mpc-1.2.1
rm -rf $item
tar xvf $item.tar.gz 
pushd $item
./configure --prefix=$PREFIX --with-gnu-ld --enable-static --enable-shared --with-gmp=$PREFIX --with-mpfr=$PREFIX --host=$TARGET
make -j8 && make install
popd

# https://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz
item=libtool-2.4.6
rm -rf $item
tar xvf $item.tar.gz 
pushd $item
./configure --prefix=$PREFIX --enable-static --enable-shared --host=$TARGET --with-sysroot=$SYSROOT --program-prefix=$TARGET-
make -j8 && make install
popd

# gcc
# the build-sysroot must be set because the sysroot is a subpath of prefix. In that case, the 
# configure script makes is relative to where gcc is, so that it's relocatable. Unfortunately, 
# that works for USING the compiler, but not for BUILDING it (during this phase below)
item=gcc-12.2.0
rm -rf $item
tar xvf $item.tar.xz 
pushd $item
mkdir -p build && cd build
../configure --without-headers --with-gnu-as --with-gnu-ld --disable-nls --enable-languages=c,c++ --enable-libssp --enable-ld --disable-libitm --disable-libquadmath --target=$TARGET --prefix=$PREFIX --with-gmp=$PREFIX --with-mpc=$PREFIX --with-mpfr=$PREFIX --disable-libgomp --with-sysroot=$SYSROOT --with-build-sysroot=$SYSROOT
make -j8 && make install
popd

exit

#Get FreeBSD libs/headers, extract

#with that method using sysroot, no need to fix anylink
# tar cvf ~freebsd.tar /lib /usr/include/ /usr/lib/ /usr/lib32/
# cd $SYSROOT
# tar xvf ~freebsd.tar

#otherwise, copy into another opt/freebsd dir
# tar -xf /tmp/base.txz ./lib/ ./usr/lib/ ./usr/include/
# cd /opt/freebsd/usr/lib 
# find . -xtype l|xargs ls -l|grep ' /lib/' | awk '{print "ln -sf /opt/freebsd13.1"$11 " " $9}' | /bin/sh
# and fix "include as well 
