#!/bin/sh


# http://www.linuxfromscratch.org/lfs/view/development/chapter05/gcc-pass1.html
# https://gcc.gnu.org/install/configure.html
# https://preshing.com/20141119/how-to-build-a-gcc-cross-compiler/
# https://istarc.wordpress.com/2014/07/21/stm32f4-build-your-toolchain-from-scratch/
# https://github.com/istarc/stm32/blob/master/build-ARM-toolchain/build.sh
# http://www.ifp.illinois.edu/~nakazato/tips/xgcc.html

steps=(	"download:10"
		"unpack:20"
		"build:30"
		"build-libs:34" "build-binutils:38" "build-gcc-1:42" "build-newlib:46" "build-newlib-nano:48" "build-gcc-2:100" "build-gdb:200")

opts=( "stop:stop_after_phase" )

start_phase=0;
stop_after_phase=0;

for a in "$@"; do
	for kv in "${steps[@]}" ; do
		if [ x"$a" == x"${kv%%:*}" ]; then start_phase=${kv#*:}; fi
	done
	for kv in "${opts[@]}" ; do
		if [ x"$a" == x"${kv%%:*}" ]; then v=${kv#*:}; eval "${v}=1"; fi
	done
	if [[ "$a" =~ "-help" ]] || [[ "$a" =~ "-h"  ]] ; then
		echo "available commands:"
		for kv in "${steps[@]}" ; do
			echo "  ${kv%%:*}"
		done

		echo "available options:"
		for kv in "${opts[@]}" ; do
			echo "  ${kv%%:*}"
		done
		exit
	fi
done


PREFIX_ROOT=`pwd`
PREFIX="$PREFIX_ROOT/_toolchain"
TARGET=arm-none-eabi
CPU=cortex-m0 #armv6-m 
FPU=auto
FLOAT=soft #could be none, I guess
HW_OPTS="--with-cpu=$CPU --with-fpu=$FPU --with-float=$FLOAT --with-mode=thumb"

function eex
{
	echo "Error: $1 ($?)"
	exit 1
}

function download()
{
	local url=$1
	local url_sig="$1.sig"
	local arch=${url##*/}
	echo "> downloading $url"
	if [ ! -e "$arch.success" ]; then
		curl -L -C - -O $url || exx "Failed to download $url"
		echo "$url" > "$arch".success
		#curl -L -C - -O $url_sig || exx "Failed to download $url_sig"
	else
		echo "  already downloaded"
	fi
}

if [ $start_phase -le 10 ]; then

	d="_original"
	mkdir -p $d

	(cd $d; download "https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz")
	(cd $d; download "https://www.mpfr.org/mpfr-current/mpfr-4.0.2.tar.xz")
	(cd $d; download "https://ftp.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz")
	(cd $d; download "http://isl.gforge.inria.fr/isl-0.22.tar.gz")
	(cd $d; download "ftp://sourceware.org/pub/newlib/newlib-3.1.0.tar.gz")
	(cd $d; download "https://ftp.gnu.org/gnu/binutils/binutils-2.33.1.tar.xz")

	#(cd $d; download "https://salsa.debian.org/electronics-team/toolchains/picolibc/-/archive/3.1.0.2019.08.14/picolibc-3.1.0.2019.08.14.tar.gz")
	(cd $d; download "http://ftp.task.gda.pl/pub/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.xz")
	(cd $d; download "https://ftp.gnu.org/gnu/gdb/gdb-8.3.tar.xz")

	if [ $stop_after_phase -eq 1 ]; then echo "Stop requested"; exit 0; fi
fi

if [ $start_phase -le 20 ]; then
	d="_unpacked"
	s="_original"
	mkdir -p $d

	for f in `ls "$s"`; do
		if [ x${f##*.} == x"sig" ]; then continue; fi
		dir=${f%.tar.*}
		base=${dir%%-*}
		if [ -e "$d/$base" ]; then continue; fi #eex "$d/$base already exists. Delete before unpacking into it again"; fi
		echo "> unpack $f into $d/$base"
		tar -xf "$s/$f" -C "$d"
		mv "$d/$dir" "$d/$base"
	done


	rm -rf $d/gcc/gmp && mv -f $d/gmp $d/gcc/
	rm -rf $d/gcc/mpfr && mv -f $d/mpfr $d/gcc/
	rm -rf $d/gcc/mpc && mv -f $d/mpc $d/gcc/
	#rm -rf $d/gcc/isl && mv -f $d/isl $d/gcc/

	if [ $stop_after_phase -eq 1 ]; then echo "Stop requested"; exit 0; fi
fi

PREREQ="--with-gmp=$PREFIX \
		--with-mpfr=$PREFIX \
		--with-mpc=$PREFIX \
		--with-isl=$PREFIX"

s="_unpacked"
d="_derived"
libs=(`ls "$s/"`)
mkdir -p ${libs[@]/#/$d/}
mkdir -p _derived/newlib_nano

if (( 0 )); then # -a $start_phase -le 34 ]; then

	(cd "$d/gmp";
		../../$s/gmp/configure --prefix=$PREFIX --enable-cxx
		make || eex "failed to make gmp"
		make check || eex "failed to check gmp"
		make install || eex "failed to install gmp"
	)

	(cd "$d/mpfr";
		../../$s/mpfr/configure --prefix=$PREFIX --disable-dependency-tracking --disable-silent-rules
		make || eex "failed to make mpfr"
		make check || eex "failed to check mpfr"
		make install || eex "failed to install mpfr"
	)

	(cd "$d/mpc";
		../../$s/mpc/configure --prefix=$PREFIX --disable-dependency-tracking --with-gmp=$PREFIX --with-mpfr=$PREFIX
		make || eex "failed to make mpc"
		make check || eex "failed to check mpc"
		make install || eex "failed to install mpc"
	)

	(cd "$d/isl";
		../../$s/isl/configure --prefix=$PREFIX --disable-dependency-tracking --with-gmp=$PREFIX
		make || eex "failed to make isl"
		make check || eex "failed to check isl"
		make install || eex "failed to install isl"
	)
	if [ $stop_after_phase -eq 1 ]; then echo "Stop requested"; exit 0; fi
fi

if [ $start_phase -le 38 ]; then

	(cd "$d/binutils";
		../../$s/binutils/configure \
			--prefix=$PREFIX \
			--target=$TARGET \
			$HW_OPTS \
			--with-gnu-as \
			--with-gnu-ld \
			--disable-nls
			# --disable-multilib

		make -j4 all || eex "failed to make binutils"
		make install || eex "failed to install binutils"
	)
	if [ $stop_after_phase -eq 1 ]; then echo "Stop requested"; exit 0; fi
fi

export PATH=$PATH:${PREFIX}:${PREFIX}/bin

if [ $start_phase -le 42 ]; then

			#$PREREQ \
 
	(cd "$d/gcc";
		../../_unpacked/gcc/configure \
			--prefix=$PREFIX \
			--target=$TARGET \
			$HW_OPTS \
			--enable-languages=c,c++ \
			--with-system-zlib \
			--with-newlib \
			--without-headers \
			--with-gnu-as \
			--with-gnu-ld \
			--disable-nls \
			--disable-libssp \
			--disable-shared \
			--disable-threads \
			--disable-tls \
			--disable-libitm \
			--disable-libquadmath \
			--disable-libmudflap \
			--disable-libatomic \
			--disable-libgomp \
			--disable-libvtv \
			--disable-decimal-float \
			--disable-libstdcxx
			# --disable-multilib

		make -j4 all-gcc || eex "failed to make gcc (bootstrap)"
		make install-gcc || eex "failed to intall gcc (bootstrap)"

	)
	if [ $stop_after_phase -eq 1 ]; then echo "Stop requested"; exit 0; fi
fi

if [ $start_phase -le 46 ]; then

	(cd "$d/newlib";
		../../$s/newlib/configure \
			--prefix=$PREFIX \
			--target=$TARGET \
			$HW_OPTS \
			--with-gnu-as \
			--with-gnu-ld \
			--without-isl \
			--disable-nls \
			--disable-libssp \
			--disable-threads \
			--disable-tls \
			--disable-libquadmath \
			--disable-newlib-supplied-syscalls
			#--with-build-time-tools=$PREFIX/arm-none-eabi/bin
			#--disable-multilib
		make -j4 all || eex "failed to build make newlib"
		make install || eex "failed to install newlib"
	)
	
	if [ $stop_after_phase -eq 1 ]; then echo "Stop requested"; exit 0; fi
fi

if [ $start_phase -le 48 ]; then
	PREFIX_NANO="$PREFIX_ROOT/_newlib-nano"
	(cd "$d/newlib_nano";
		../../$s/newlib/configureq \
			--prefix=$PREFIX_NANO \
			--target=$TARGET \
			$HW_OPTS \
			--with-gnu-as \
			--with-gnu-ld \
			--without-isl \
			--disable-nls \
			--disable-libssp \
			--disable-threads \
			--disable-tls \
			--disable-libquadmath \
			--enable-newlib-reent-small --disable-newlib-fvwrite-in-streamio \
			--disable-newlib-fseek-optimization --disable-newlib-wide-orient --enable-newlib-nano-malloc \
			--disable-newlib-unbuf-stream-opt --enable-lite-exit --enable-newlib-global-atexit \
			--disable-newlib-supplied-syscalls
		#make -j4 all || eex "failed to build make newlib nano"
		#make install || eex "failed to install newlib nano"
	)

	for c in crt0.o libc.a libg.a libstdc++.a; do
		found=(`find "$PREFIX_NANO" -name $c`)
	   	for ff in "${found[@]}"; do
			f="${ff##$PREFIX_NANO/}"
			ext="${f##*.}"
			df="${f%.*}_nano.$ext"
			echo "copying" "$f" to "$df"
		   	cp "$PREFIX_NANO/$f" "$PREFIX/$df"
		done
	done
	
	if [ $stop_after_phase -eq 1 ]; then echo "Stop requested"; exit 0; fi
fi

if [ $start_phase -le 100 ]; then
			# $PREREQ
			#--disable-libstdcxx

	(cd "$d/gcc";
		../../$s/gcc/configure \
			--prefix=$PREFIX \
			--target=$TARGET \
			$HW_OPTS \
			--enable-languages="c,c++" \
			--with-system-zlib \
			--with-newlib \
			--without-headers \
			--disable-shared \
			--with-gnu-as \
			--with-gnu-ld \
			--disable-nls \
			--disable-shared \
			--disable-libssp \
			--disable-threads \
			--disable-tls \
			--disable-libitm \
			--disable-libquadmath \
			--disable-libmudflap \
			--disable-decimal-float
			--disable-libatomic \ 
			--disable-libgomp \
			--disable-libvtv
			# --disable-multilib

		make -j4 all || eex "failed to make gcc"
		make install || eex "failed to install gcc"
	)
	if [ $stop_after_phase -eq 1 ]; then echo "Stop requested"; exit 0; fi
fi

if [ $start_phase -le 200 ]; then

	#		$PREREQ

	(cd "$d/gdb";
		../../$s/gdb/configure \
			--prefix=$PREFIX \
			--target=$TARGET \
			--with-system-zlib \
			--disable-nls \
			--disable-libssp \
			--disable-libquadmath \
			--disable-libmudflap

		make -j4 all || eex "failed to make gdb"
		make install || eex "failed to install gdb"
	)

	if [ $stop_after_phase -eq 1 ]; then echo "Stop requested"; exit 0; fi
fi
