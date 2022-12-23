srcdir := /media/stu/diska/rv-tool/riscv-gnu-toolchain
builddir := /media/stu/diska/rv-tool/riscv-gnu-toolchain
INSTALL_DIR := /media/stu/diska/rv-tool/install

GCC_SRCDIR := $(srcdir)/gcc
BINUTILS_SRCDIR := $(srcdir)/binutils
NEWLIB_SRCDIR := $(srcdir)/newlib
GLIBC_SRCDIR := $(srcdir)/glibc
MUSL_SRCDIR := $(srcdir)/musl
LINUX_HEADERS_SRCDIR := $(srcdir)/linux-headers/include
GDB_SRCDIR := $(srcdir)/gdb
QEMU_SRCDIR := $(srcdir)/qemu
SPIKE_SRCDIR := $(srcdir)/spike
PK_SRCDIR := $(srcdir)/pk

SIM ?= qemu

ifeq ($(srcdir)/riscv-gcc,$(GCC_SRCDIR))
# We need a relative source dir for the gcc configure, to make msys2 mingw64
# builds work.  Mayberelsrcdir is relative if a relative path was used to run
# configure, otherwise absolute, so we have to check.
mayberelsrcdir := .
gccsrcdir := $(shell case $(mayberelsrcdir) in \
		  ([\\/]* | ?:[\\/]*)  echo $(mayberelsrcdir)/riscv-gcc ;; \
		  (*)  echo ../$(mayberelsrcdir)/riscv-gcc ;; \
		esac)
else
gccsrcdir := $(abspath $(GCC_SRCDIR))
endif

WITH_ARCH ?= --with-arch=rv64imafdc
WITH_ABI ?= --with-abi=lp64d
WITH_TUNE ?= --with-tune=rocket
WITH_ISA_SPEC ?= --with-isa-spec=2.2
SYSROOT := $(INSTALL_DIR)/sysroot
ENABLE_LIBSANITIZER ?= --disable-libsanitizer
QEMU_TARGETS ?= riscv64-linux-user,riscv32-linux-user

SHELL := /bin/sh
AWK := /usr/bin/gawk
SED := /usr/bin/sed
PATH := $(INSTALL_DIR)/bin:$(PATH)

# Check to see if we need wrapper scripts for awk/sed (which point to
# gawk/gsed on platforms where these aren't the default), otherwise
# don't override these as the wrappers don't always work.
ifneq (/usr/bin/sed,/bin/sed)
	PATH := $(builddir)/scripts/wrapper/sed:$(PATH)
endif
ifneq (/usr/bin/gawk,/usr/bin/gawk)
	PATH := $(builddir)/scripts/wrapper/awk:$(PATH)
endif

export PATH AWK SED

MULTILIB_FLAGS := --disable-multilib
MULTILIB_GEN := 
ifeq ($(MULTILIB_GEN),)
NEWLIB_MULTILIB_NAMES := rv64imafdc-lp64d
GCC_MULTILIB_FLAGS := $(MULTILIB_FLAGS)
else
NEWLIB_MULTILIB_NAMES := $(shell echo "$(MULTILIB_GEN)" | $(SED) 's/;/\n/g'| $(AWK) '{split($$0,a,"-"); printf "%s-%s ", a[1],a[2]}')
GCC_MULTILIB_FLAGS := $(MULTILIB_FLAGS) --with-multilib-generator="$(MULTILIB_GEN)"
endif
GLIBC_MULTILIB_NAMES := rv64imafdc-lp64d
GCC_CHECKING_FLAGS := 

XLEN := $(shell echo $(WITH_ARCH) | tr A-Z a-z | sed 's/.*rv\([0-9]*\).*/\1/')
ifneq ($(XLEN),32)
	XLEN := 64
endif

make_tuple = riscv$(1)-unknown-$(2)
LINUX_TUPLE  ?= $(call make_tuple,$(XLEN),linux-gnu)
NEWLIB_TUPLE ?= $(call make_tuple,$(XLEN),elf)
MUSL_TUPLE ?= $(call make_tuple,$(XLEN),linux-musl)

CFLAGS_FOR_TARGET := $(CFLAGS_FOR_TARGET_EXTRA)  -mcmodel=medlow
CXXFLAGS_FOR_TARGET := $(CXXFLAGS_FOR_TARGET_EXTRA)  -mcmodel=medlow
ASFLAGS_FOR_TARGET := $(ASFLAGS_FOR_TARGET_EXTRA) -mcmodel=medlow
# --with-expat is required to enable XML support used by OpenOCD.
BINUTILS_TARGET_FLAGS := --with-expat=yes $(BINUTILS_TARGET_FLAGS_EXTRA)
BINUTILS_NATIVE_FLAGS := $(BINUTILS_NATIVE_FLAGS_EXTRA)
GDB_TARGET_FLAGS := --with-expat=yes $(GDB_TARGET_FLAGS_EXTRA)
GDB_NATIVE_FLAGS := $(GDB_NATIVE_FLAGS_EXTRA)

GLIBC_TARGET_FLAGS := $(GLIBC_TARGET_FLAGS_EXTRA)
GLIBC_CC_FOR_TARGET ?= $(LINUX_TUPLE)-gcc
GLIBC_CXX_FOR_TARGET ?= $(LINUX_TUPLE)-g++
GLIBC_TARGET_BOARDS ?= $(shell echo "$(GLIBC_MULTILIB_NAMES)" | sed 's!\([_a-z0-9]*\)-\([_a-z0-9]*\)!riscv-sim/-march=\1/-mabi=\2/-mcmodel=medlow!g')

NEWLIB_CC_FOR_TARGET ?= $(NEWLIB_TUPLE)-gcc
NEWLIB_CXX_FOR_TARGET ?= $(NEWLIB_TUPLE)-g++
NEWLIB_TARGET_BOARDS ?= $(shell echo "$(NEWLIB_MULTILIB_NAMES)" | sed 's!\([_a-z0-9]*\)-\([_a-z0-9]*\)!riscv-sim/-march=\1/-mabi=\2/-mcmodel=medlow!g')
NEWLIB_NANO_TARGET_BOARDS ?= $(shell echo "$(NEWLIB_MULTILIB_NAMES)" | sed 's!\([_a-z0-9]*\)-\([_a-z0-9]*\)!riscv-sim-nano/-march=\1/-mabi=\2/-mcmodel=medlow!g')

MUSL_TARGET_FLAGS := $(MUSL_TARGET_FLAGS_EXTRA)
MUSL_CC_FOR_TARGET ?= $(MUSL_TUPLE)-gcc
MUSL_CXX_FOR_TARGET ?= $(MUSL_TUPLE)-g++

CONFIGURE_HOST   = 

all: newlib
newlib: stamps/build-gcc-newlib-stage2
linux: stamps/build-gcc-linux-stage2
ifneq (,$(findstring riscv32,$(MUSL_TUPLE)))
.PHONY: musl
musl:
	@echo "musl only supports 64bit builds." && exit 1
else
musl: stamps/build-gcc-musl-stage2
endif
ifeq (--enable-gdb,--enable-gdb)
newlib: stamps/build-gdb-newlib
linux: stamps/build-gdb-linux
endif
linux-native: stamps/build-gcc-linux-native

.PHONY: build-binutils build-gdb build-gcc1 build-libc build-gcc2 build-qemu
build-binutils: stamps/build-binutils-newlib
build-gdb: stamps/build-gdb-newlib
build-gcc%: stamps/build-gcc-newlib-stage%
ifeq (newlib,linux)
build-libc: $(addprefix stamps/build-glibc-linux-,$(GLIBC_MULTILIB_NAMES))
else
build-libc: stamps/build-newlib stamps/build-newlib-nano \
	stamps/merge-newlib-nano
endif
build-qemu: stamps/build-qemu

REGRESSION_TEST_LIST = gcc

.PHONY: check
check: check-newlib
.PHONY: check-linux check-newlib
check-linux: $(patsubst %,check-%-linux,$(REGRESSION_TEST_LIST))
check-newlib: $(patsubst %,check-%-newlib,$(REGRESSION_TEST_LIST))
check-newlib-nano: $(patsubst %,check-%-newlib-nano,$(REGRESSION_TEST_LIST))
.PHONY: check-gcc check-gcc-linux check-gcc-newlib check-gcc-newlib-nano
check-gcc: check-gcc-newlib
check-gcc-linux: stamps/check-gcc-linux
check-gcc-newlib: stamps/check-gcc-newlib
check-gcc-newlib-nano: stamps/check-gcc-newlib-nano
.PHONY: check-glibc-linux
check-glibc-linux: $(addprefix stamps/check-glibc-linux-,$(GLIBC_MULTILIB_NAMES))
.PHONY: check-dhrystone check-dhrystone-linux check-dhrystone-newlib
check-dhrystone: check-dhrystone-newlib
.PHONY: check-binutils check-binutils-linux check-binutils-newlib
check-binutils: check-binutils-newlib
check-binutils-linux: stamps/check-binutils-linux
check-binutils-newlib: stamps/check-binutils-newlib
check-binutils-newlib-nano: stamps/check-binutils-newlib-nano
.PHONY: check-gdb check-gdb-linux check-gdb-newlib
check-gdb: check-gdb-newlib
check-gdb-linux: stamps/check-gdb-linux
check-gdb-newlib: stamps/check-gdb-newlib
check-gdb-newlib-nano: stamps/check-gdb-newlib-nano

.PHONY: report
report: report-newlib
.PHONY: report-linux report-newlib report-newlib-nano
report-linux: $(patsubst %,report-%-linux,$(REGRESSION_TEST_LIST))
report-newlib: $(patsubst %,report-%-newlib,$(REGRESSION_TEST_LIST))
report-newlib-nano: $(patsubst %,report-%-newlib-nano,$(REGRESSION_TEST_LIST))
.PHONY: report-gcc
report-gcc: report-gcc-newlib
.PHONY: report-dhrystone
report-dhrystone: report-dhrystone-newlib
.PHONY: report-binutils
report-binutils: report-binutils-newlib
.PHONY: report-gdb
report-gdb: report-gdb-newlib

.PHONY: build-sim
ifeq ($(SIM),qemu)
QEMU_CPU=$(shell $(srcdir)/scripts/march-to-cpu-opt $(WITH_ARCH))
SIM_PATH:=$(srcdir)/scripts/wrapper/qemu
SIM_PREPARE:=PATH="$(SIM_PATH):$(INSTALL_DIR)/bin:$(PATH)" RISC_V_SYSROOT="$(SYSROOT)" QEMU_CPU="$(QEMU_CPU)"
SIM_STAMP:= stamps/build-qemu
else
ifeq ($(SIM),spike)
# Using spike simulator.
SIM_PATH:=$(srcdir)/scripts/wrapper/spike
SIM_PREPARE:=PATH="$(SIM_PATH):$(INSTALL_DIR)/bin:$(PATH)" PK_PATH="$(INSTALL_DIR)/$(NEWLIB_TUPLE)/bin/" ARCH_STR="$(WITH_ARCH)"
SIM_STAMP:= stamps/build-spike
ifneq (,$(findstring rv32,$(NEWLIB_MULTILIB_NAMES)))
SIM_STAMP+= stamps/build-pk32
endif
ifneq (,$(findstring rv64,$(NEWLIB_MULTILIB_NAMES)))
SIM_STAMP+= stamps/build-pk64
endif
else
ifeq ($(SIM),gdb)
# Using gdb simulator.
SIM_PATH:=$(INSTALL_DIR)/bin
SIM_PREPARE:=
else
$(error "Only support SIM=spike, SIM=gdb or SIM=qemu (default).")
endif
endif
endif

build-sim: $(SIM_STAMP)

stamps/check-write-permission:
	mkdir -p $(INSTALL_DIR)/.test || \
		(echo "Sorry, you don't have permission to write to" \
		 "'$(INSTALL_DIR)'. Please make sure that the location is " \
		 "writable or use --prefix to specify another destination.'" \
		 && exit 1)
	rm -r $(INSTALL_DIR)/.test
	mkdir -p $(dir $@) && touch $@

stamps/build-linux-headers:
	mkdir -p $(SYSROOT)/usr/
ifdef LINUX_HEADERS_SRCDIR
	cp -a $(LINUX_HEADERS_SRCDIR) $(SYSROOT)/usr/
else
	cp -a $(srcdir)/linux-headers/include $(SYSROOT)/usr/
endif
	mkdir -p $(dir $@) && touch $@

#
# Rule for auto init submodules
#

ifeq ($(findstring $(srcdir),$(GCC_SRCDIR)),$(srcdir))
GCC_SRC_GIT := $(GCC_SRCDIR)/.git
else
GCC_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(BINUTILS_SRCDIR)),$(srcdir))
BINUTILS_SRC_GIT := $(BINUTILS_SRCDIR)/.git
else
BINUTILS_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(GDB_SRCDIR)),$(srcdir))
GDB_SRC_GIT := $(GDB_SRCDIR)/.git
else
GDB_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(NEWLIB_SRCDIR)),$(srcdir))
NEWLIB_SRC_GIT := $(NEWLIB_SRCDIR)/.git
else
NEWLIB_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(GLIBC_SRCDIR)),$(srcdir))
GLIBC_SRC_GIT := $(GLIBC_SRCDIR)/.git
else
GLIBC_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(MUSL_SRCDIR)),$(srcdir))
MUSL_SRC_GIT := $(MUSL_SRCDIR)/.git
else
MUSL_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(QEMU_SRCDIR)),$(srcdir))
QEMU_SRC_GIT := $(QEMU_SRCDIR)/.git
else
QEMU_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(SPIKE_SRCDIR)),$(srcdir))
SPIKE_SRC_GIT := $(SPIKE_SRCDIR)/.git
else
SPIKE_SRC_GIT :=
endif

ifneq ("$(wildcard $(GCC_SRCDIR)/.git)","")
GCCPKGVER := g$(shell git -C $(GCC_SRCDIR) describe --always --dirty --exclude '*')
else
GCCPKGVER :=
endif

$(srcdir)/%/.git:
	cd $(srcdir) && \
	flock `git rev-parse --git-dir`/config git submodule init $(dir $@) && \
	flock `git rev-parse --git-dir`/config git submodule update $(dir $@)

#
# GLIBC
#

stamps/build-binutils-linux: $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) stamps/check-write-permission
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(GLIBC_CC_FOR_TARGET) $</configure \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		$(MULTILIB_FLAGS) \
		 \
		--disable-werror \
		--disable-nls \
		$(BINUTILS_TARGET_FLAGS) \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		$(WITH_ISA_SPEC)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gdb-linux: $(GDB_SRCDIR) $(GDB_SRC_GIT)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(GLIBC_CC_FOR_TARGET) $</configure \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		$(MULTILIB_FLAGS) \
		 \
		--disable-werror \
		--disable-nls \
		$(GDB_TARGET_FLAGS) \
		--enable-gdb \
		--disable-gas \
		--disable-binutils \
		--disable-ld \
		--disable-gold \
		--disable-gprof
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-glibc-linux-headers: $(GLIBC_SRCDIR) $(GLIBC_SRC_GIT) stamps/build-gcc-linux-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && CC="$(GLIBC_CC_FOR_TARGET)" $</configure \
		--host=$(LINUX_TUPLE) \
		--prefix=$(SYSROOT)/usr \
		--enable-shared \
		--with-headers=$(LINUX_HEADERS_SRCDIR) \
		--disable-multilib \
		--enable-kernel=3.0.0
	$(MAKE) -C $(notdir $@) install-headers
	mkdir -p $(dir $@) && touch $@

stamps/build-glibc-linux-%: $(GLIBC_SRCDIR) $(GLIBC_SRC_GIT) stamps/build-gcc-linux-stage1
ifeq ($(MULTILIB_FLAGS),--enable-multilib)
	$(eval $@_ARCH := $(word 4,$(subst -, ,$@)))
	$(eval $@_ABI := $(word 5,$(subst -, ,$@)))
else
	$(eval $@_ARCH := )
	$(eval $@_ABI := )
endif
	$(eval $@_LIBDIRSUFFIX := $(if $($@_ABI),$(shell echo $($@_ARCH) | sed 's/.*rv\([0-9]*\).*/\1/')/$($@_ABI),))
	$(eval $@_XLEN := $(if $($@_ABI),$(shell echo $($@_ARCH) | sed 's/.*rv\([0-9]*\).*/\1/'),$(XLEN)))
	$(eval $@_CFLAGS := $(if $($@_ABI),-march=$($@_ARCH) -mabi=$($@_ABI),))
	$(eval $@_LIBDIROPTS := $(if $@_LIBDIRSUFFIX,--libdir=/usr/lib$($@_LIBDIRSUFFIX) libc_cv_slibdir=/lib$($@_LIBDIRSUFFIX) libc_cv_rtlddir=/lib,))
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && \
		CC="$(GLIBC_CC_FOR_TARGET) $($@_CFLAGS)" \
		CXX="this-is-not-the-compiler-youre-looking-for" \
		CFLAGS="$(CFLAGS_FOR_TARGET) -g -O2 $($@_CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS_FOR_TARGET) -g -O2 $($@_CFLAGS)" \
		ASFLAGS="$(ASFLAGS_FOR_TARGET) $($@_CFLAGS)" \
		$</configure \
		--host=$(call make_tuple,$($@_XLEN),linux-gnu) \
		--prefix=/usr \
		--disable-werror \
		--enable-shared \
		--enable-obsolete-rpc \
		--with-headers=$(LINUX_HEADERS_SRCDIR) \
		$(MULTILIB_FLAGS) \
		--enable-kernel=3.0.0 \
		$(GLIBC_TARGET_FLAGS) \
		$($@_LIBDIROPTS)
	$(MAKE) -C $(notdir $@)
	+flock $(SYSROOT)/.lock $(MAKE) -C $(notdir $@) install install_root=$(SYSROOT)
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-linux-stage1: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-binutils-linux \
                               stamps/build-linux-headers
	if test -f $</contrib/download_prerequisites && test "false" = "true"; then cd $< && ./contrib/download_prerequisites; fi
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		--with-newlib \
		--without-headers \
		--disable-shared \
		--disable-threads \
		--with-system-zlib \
		--enable-tls \
		--enable-languages=c \
		--disable-libatomic \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-bootstrap \
		--src=$(gccsrcdir) \
		$(GCC_CHECKING_FLAGS) \
		$(MULTILIB_FLAGS) \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		CFLAGS_FOR_TARGET="-O2 $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@) inhibit-libc=true all-gcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true install-gcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true all-target-libgcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true install-target-libgcc
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-linux-stage2: $(GCC_SRCDIR) $(GCC_SRC_GIT) $(addprefix stamps/build-glibc-linux-,$(GLIBC_MULTILIB_NAMES)) \
                               stamps/build-glibc-linux-headers
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		--with-pkgversion="$(GCCPKGVER)" \
		--with-system-zlib \
		--enable-shared \
		--enable-tls \
		--enable-languages=c,c++,fortran \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		$(ENABLE_LIBSANITIZER) \
		--disable-nls \
		--disable-bootstrap \
		--src=$(gccsrcdir) \
		$(GCC_CHECKING_FLAGS) \
		$(MULTILIB_FLAGS) \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		CFLAGS_FOR_TARGET="-O2 $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	cp -a $(INSTALL_DIR)/$(LINUX_TUPLE)/lib* $(SYSROOT)
	mkdir -p $(dir $@) && touch $@

stamps/build-binutils-linux-native: $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) stamps/build-gcc-linux-stage2 stamps/check-write-permission
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--host=$(LINUX_TUPLE) \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR)/native \
		$(MULTILIB_FLAGS) \
		 \
		--disable-werror \
		--disable-nls \
		$(BINUTILS_NATIVE_FLAGS) \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		$(WITH_ISA_SPEC)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-linux-native: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-gcc-linux-stage2 stamps/build-binutils-linux-native
	if test -f $</contrib/download_prerequisites; then cd $< && ./contrib/download_prerequisites; fi
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--host=$(LINUX_TUPLE) \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR)/native \
		--without-system-zlib \
		--enable-shared \
		--enable-tls \
		--enable-languages=c,c++,fortran \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-nls \
		--disable-bootstrap \
                --with-native-system-header-dir=$(INSTALL_DIR)/native/include \
		$(GCC_CHECKING_FLAGS) \
		$(MULTILIB_FLAGS) \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	cp -a $(INSTALL_DIR)/$(LINUX_TUPLE)/lib* $(SYSROOT)
	mkdir -p $(dir $@) && touch $@

#
# NEWLIB
#

stamps/build-binutils-newlib: $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) stamps/check-write-permission
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(NEWLIB_CC_FOR_TARGET) $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		 \
		--disable-werror \
		$(BINUTILS_TARGET_FLAGS) \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		$(WITH_ISA_SPEC)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gdb-newlib: $(GDB_SRCDIR) $(GDB_SRC_GIT)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(NEWLIB_CC_FOR_TARGET) $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		 \
		--disable-werror \
		$(GDB_TARGET_FLAGS) \
		--enable-gdb \
		--disable-gas \
		--disable-binutils \
		--disable-ld \
		--disable-gold \
		--disable-gprof
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-newlib-stage1: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-binutils-newlib
	if test -f $</contrib/download_prerequisites && test "false" = "true"; then cd $< && ./contrib/download_prerequisites; fi
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--disable-shared \
		--disable-threads \
		--disable-tls \
		--enable-languages=c,c++ \
		--with-system-zlib \
		--with-newlib \
		--with-sysroot=$(INSTALL_DIR)/$(NEWLIB_TUPLE) \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-tm-clone-registry \
		--src=$(gccsrcdir) \
		$(GCC_CHECKING_FLAGS) \
		$(GCC_MULTILIB_FLAGS) \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		CFLAGS_FOR_TARGET="-Os $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-Os $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@) all-gcc
	$(MAKE) -C $(notdir $@) install-gcc
	mkdir -p $(dir $@) && touch $@

stamps/build-newlib: $(NEWLIB_SRCDIR) $(NEWLIB_SRC_GIT) stamps/build-gcc-newlib-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--enable-newlib-io-long-double \
		--enable-newlib-io-long-long \
		--enable-newlib-io-c99-formats \
		--enable-newlib-register-fini \
		CFLAGS_FOR_TARGET="-O2 -D_POSIX_MODE -ffunction-sections -fdata-sections $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 -D_POSIX_MODE -ffunction-sections -fdata-sections $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-newlib-nano: $(NEWLIB_SRCDIR) $(NEWLIB_SRC_GIT) stamps/build-gcc-newlib-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(builddir)/install-newlib-nano \
		--enable-newlib-reent-small \
		--disable-newlib-fvwrite-in-streamio \
		--disable-newlib-fseek-optimization \
		--disable-newlib-wide-orient \
		--enable-newlib-nano-malloc \
		--disable-newlib-unbuf-stream-opt \
		--enable-lite-exit \
		--enable-newlib-global-atexit \
		--enable-newlib-nano-formatted-io \
		--disable-newlib-supplied-syscalls \
		--disable-nls \
		CFLAGS_FOR_TARGET="-Os -ffunction-sections -fdata-sections $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-Os -ffunction-sections -fdata-sections $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/merge-newlib-nano: stamps/build-newlib-nano stamps/build-newlib
# Copy nano library files into newlib install dir.
	set -e; \
        for ml in `$(INSTALL_DIR)/bin/$(NEWLIB_TUPLE)-gcc --print-multi-lib`; \
	do \
	    mld=`echo $${ml} | sed -e 's/;.*$$//'`; \
	    cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/lib/$${mld}/libc.a \
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/lib/$${mld}/libc_nano.a; \
	    cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/lib/$${mld}/libm.a \
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/lib/$${mld}/libm_nano.a; \
	    cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/lib/$${mld}/libg.a \
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/lib/$${mld}/libg_nano.a; \
	    cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/lib/$${mld}/libgloss.a\
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/lib/$${mld}/libgloss_nano.a; \
	    cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/lib/$${mld}/crt0.o\
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/lib/$${mld}/crt0.o; \
	done
# Copy nano header files into newlib install dir.
	mkdir -p $(INSTALL_DIR)/$(NEWLIB_TUPLE)/include/newlib-nano; \
	cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/include/newlib.h \
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/include/newlib-nano/newlib.h; \
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-newlib-stage2: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-newlib \
		stamps/merge-newlib-nano
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--disable-shared \
		--disable-threads \
		--enable-languages=c,c++ \
		--with-pkgversion="$(GCCPKGVER)" \
		--with-system-zlib \
		--enable-tls \
		--with-newlib \
		--with-sysroot=$(INSTALL_DIR)/$(NEWLIB_TUPLE) \
		--with-native-system-header-dir=/include \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-tm-clone-registry \
		--src=$(gccsrcdir) \
		$(GCC_CHECKING_FLAGS) \
		$(GCC_MULTILIB_FLAGS) \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		CFLAGS_FOR_TARGET="-Os $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-Os $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

#
# MUSL
#

stamps/build-binutils-musl: $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) stamps/check-write-permission
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(MUSL_CC_FOR_TARGET) $</configure \
		--target=$(MUSL_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		$(MULTILIB_FLAGS) \
		 \
		--disable-werror \
		--disable-nls \
		$(BINUTILS_TARGET_FLAGS) \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		$(WITH_ISA_SPEC)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-musl-stage1: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-binutils-musl \
                               stamps/build-linux-headers
	if test -f $</contrib/download_prerequisites && test "false" = "true"; then cd $< && ./contrib/download_prerequisites; fi
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(MUSL_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--without-headers \
		--disable-shared \
		--disable-threads \
		--with-system-zlib \
		--enable-tls \
		--enable-languages=c \
		--disable-libatomic \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-bootstrap \
		--src=$(gccsrcdir) \
		$(GCC_CHECKING_FLAGS) \
		--disable-multilib \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		CFLAGS_FOR_TARGET="-O2 $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@) inhibit-libc=true all-gcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true install-gcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true all-target-libgcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true install-target-libgcc
	mkdir -p $(dir $@) && touch $@

stamps/build-musl-linux-headers: $(MUSL_SRCDIR) $(MUSL_SRC_GIT) stamps/build-gcc-musl-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && CC="$(MUSL_CC_FOR_TARGET)" $</configure \
		--host=$(MUSL_TUPLE) \
		--prefix=$(SYSROOT)/usr \
		--enable-shared \
		--with-headers=$(LINUX_HEADERS_SRCDIR) \
		--disable-multilib \
		--enable-kernel=3.0.0
	$(MAKE) -C $(notdir $@) install-headers
	mkdir -p $(dir $@) && touch $@

stamps/build-musl-linux: $(MUSL_SRCDIR) $(MUSL_SRC_GIT) stamps/build-gcc-musl-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && \
		CC="$(MUSL_CC_FOR_TARGET) $($@_CFLAGS)" \
		CXX="$(MUSL_CXX_FOR_TARGET) $($@_CFLAGS)" \
		CFLAGS="$(CFLAGS_FOR_TARGET) -g -O2 $($@_CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS_FOR_TARGET) -g -O2 $($@_CFLAGS)" \
		ASFLAGS="$(ASFLAGS_FOR_TARGET) $($@_CFLAGS)" \
		$</configure \
		--host=$(MUSL_TUPLE) \
		--prefix=$(SYSROOT) \
		--disable-werror \
		--enable-shared \
		$(MUSL_TARGET_FLAGS)
	$(MAKE) -C $(notdir $@)
	+flock $(SYSROOT)/.lock $(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-musl-stage2: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-musl-linux \
                               stamps/build-musl-linux-headers
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	# Disable libsanitizer for now
	# https://github.com/google/sanitizers/issues/1080
	cd $(notdir $@) && $</configure \
		--target=$(MUSL_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		--with-system-zlib \
		--enable-shared \
		--enable-tls \
		--enable-languages=c,c++ \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libsanitizer \
		--disable-nls \
		--disable-bootstrap \
		--src=$(gccsrcdir) \
		$(GCC_CHECKING_FLAGS) \
		--disable-multilib \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		CFLAGS_FOR_TARGET="-O2 $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	cp -a $(INSTALL_DIR)/$(MUSL_TUPLE)/lib* $(SYSROOT)
	mkdir -p $(dir $@) && touch $@

stamps/build-spike: $(SPIKE_SRCDIR) $(SPIKE_SRC_GIT)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(INSTALL_DIR)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@)
	date > $@

stamps/build-pk32: $(PK_SRCDIR) stamps/build-gcc-newlib-stage2
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(INSTALL_DIR) \
		--host=$(NEWLIB_TUPLE) \
		--with-arch=rv32imafdc \
		--with-abi=ilp32f
	$(MAKE) -C $(notdir $@)
	cp $(notdir $@)/pk $(INSTALL_DIR)/$(NEWLIB_TUPLE)/bin/pk32
	mkdir -p $(dir $@)
	date > $@

stamps/build-pk64: $(PK_SRCDIR) stamps/build-gcc-newlib-stage2
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(INSTALL_DIR) \
		--host=$(NEWLIB_TUPLE) \
		--with-arch=rv64gc
	$(MAKE) -C $(notdir $@)
	cp $(notdir $@)/pk $(INSTALL_DIR)/$(NEWLIB_TUPLE)/bin/pk64
	mkdir -p $(dir $@)
	date > $@

stamps/build-qemu: $(QEMU_SRCDIR) $(QEMU_SRC_GIT)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(INSTALL_DIR) \
		--target-list=$(QEMU_TARGETS) \
		--interp-prefix=$(INSTALL_DIR)/sysroot \
		--python=python3
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@)
	date > $@

stamps/build-dejagnu: $(srcdir)/dejagnu $(srcdir)/dejagnu/.git
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(INSTALL_DIR)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@)
	date > $@

stamps/check-gcc-newlib: stamps/build-gcc-newlib-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gcc-newlib-stage2 check-gcc "RUNTESTFLAGS=$(RUNTESTFLAGS) --target_board='$(NEWLIB_TARGET_BOARDS)'"
	mkdir -p $(dir $@)
	date > $@

stamps/check-gcc-newlib-nano: stamps/build-gcc-newlib-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gcc-newlib-stage2 check-gcc "RUNTESTFLAGS=$(RUNTESTFLAGS) --target_board='$(NEWLIB_NANO_TARGET_BOARDS)'"
	mkdir -p $(dir $@)
	date > $@

stamps/check-gcc-linux: stamps/build-gcc-linux-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gcc-linux-stage2 check-gcc "RUNTESTFLAGS=$(RUNTESTFLAGS) --target_board='$(GLIBC_TARGET_BOARDS)'"
	mkdir -p $(dir $@)
	date > $@

stamps/check-glibc-linux-%: $(addprefix stamps/build-glibc-linux-,$(GLIBC_MULTILIB_NAMES))
	$(eval $@_BUILD_DIR := $(notdir $@))
	$(eval $@_BUILD_DIR := $(subst check-,build-,$($@_BUILD_DIR)))
	$(SIM_PREPARE) $(MAKE) -C $($@_BUILD_DIR) check
	mkdir -p $(dir $@)
	date > $@

.PHONY: check-dhrystone-newlib check-dhrystone-newlib-nano
check-dhrystone-newlib: $(patsubst %,stamps/check-dhrystone-newlib-%,$(NEWLIB_MULTILIB_NAMES))
check-dhrystone-newlib-nano: $(patsubst %,stamps/check-dhrystone-newlib-nano-%,$(NEWLIB_MULTILIB_NAMES))

stamps/check-dhrystone-newlib-%: \
		stamps/build-gcc-newlib-stage2 \
		$(SIM_STAMP) \
		$(wildcard $(srcdir)/test/benchmarks/dhrystone/*)
	$(eval $@_ARCH := $(word 4,$(subst -, ,$@)))
	$(eval $@_ABI := $(word 5,$(subst -, ,$@)))
	$(eval $@_XLEN := $(patsubst rv32%,32,$(patsubst rv64%,64,$($@_ARCH))))
	$(SIM_PREPARE) $(srcdir)/test/benchmarks/dhrystone/check -march=$($@_ARCH) -mabi=$($@_ABI) -cc=riscv$(XLEN)-unknown-elf-gcc -objdump=riscv$(XLEN)-unknown-elf-objdump -sim=riscv$($@_XLEN)-unknown-elf-run -out=$@ $(filter %.c,$^) || true

stamps/check-dhrystone-newlib-nano-%: \
		stamps/build-gcc-newlib-stage2 \
		$(SIM_STAMP) \
		$(wildcard $(srcdir)/test/benchmarks/dhrystone/*)
	$(eval $@_ARCH := $(word 5,$(subst -, ,$@)))
	$(eval $@_ABI := $(word 6,$(subst -, ,$@)))
	$(eval $@_XLEN := $(patsubst rv32%,32,$(patsubst rv64%,64,$($@_ARCH))))
	$(SIM_PREPARE) $(srcdir)/test/benchmarks/dhrystone/check -march=$($@_ARCH) -mabi=$($@_ABI) -specs=nano.specs -cc=riscv$(XLEN)-unknown-elf-gcc -objdump=riscv$(XLEN)-unknown-elf-objdump -sim=riscv$($@_XLEN)-unknown-elf-run -out=$@ $(filter %.c,$^) || true

.PHONY: check-dhrystone-linux
check-dhrystone-linux: $(patsubst %,stamps/check-dhrystone-linux-%,$(GLIBC_MULTILIB_NAMES))

stamps/check-dhrystone-linux-%: \
		stamps/build-gcc-linux-stage2 \
		$(SIM_STAMP) \
		$(wildcard $(srcdir)/test/benchmarks/dhrystone/*)
	$(eval $@_ARCH := $(word 4,$(subst -, ,$@)))
	$(eval $@_ABI := $(word 5,$(subst -, ,$@)))
	$(eval $@_XLEN := $(patsubst rv32%,32,$(patsubst rv64%,64,$($@_ARCH))))
	$(SIM_PREPARE) $(srcdir)/test/benchmarks/dhrystone/check -march=$($@_ARCH) -mabi=$($@_ABI) -cc=riscv$(XLEN)-unknown-elf-gcc -objdump=riscv$(XLEN)-unknown-elf-objdump -sim=riscv$($@_XLEN)-unknown-elf-run -out=$@ $(filter %.c,$^) || true

stamps/check-binutils-newlib: stamps/build-gcc-newlib-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-binutils-newlib check-binutils check-gas check-ld -k "RUNTESTFLAGS=--target_board='$(NEWLIB_TARGET_BOARDS)'" || true
	date > $@

stamps/check-binutils-newlib-nano: stamps/build-gcc-newlib-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-binutils-newlib check-binutils check-gas check-ld -k "RUNTESTFLAGS=--target_board='$(NEWLIB_NANO_TARGET_BOARDS)'" || true
	date > $@

stamps/check-binutils-linux: stamps/build-gcc-linux-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-binutils-linux check-binutils check-gas check-ld -k "RUNTESTFLAGS=--target_board='$(GLIBC_TARGET_BOARDS)'" || true
	date > $@

stamps/check-gdb-newlib: stamps/build-gcc-newlib-stage2 stamps/build-gdb-newlib $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gdb-newlib check-gdb -k "RUNTESTFLAGS=--target_board='$(NEWLIB_TARGET_BOARDS)'" || true
	date > $@

stamps/check-gdb-newlib-nano: stamps/build-gcc-newlib-stage2 stamps/build-gdb-newlib $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gdb-newlib check-gdb -k "RUNTESTFLAGS=--target_board='$(NEWLIB_NANO_TARGET_BOARDS)'" || true
	date > $@

stamps/check-gdb-linux: stamps/build-gcc-linux-stage2 stamps/build-gdb-linux $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gdb-linux check-gdb -k "RUNTESTFLAGS=--target_board='$(GLIBC_TARGET_BOARDS)'" || true
	date > $@

.PHONY: report-gcc-newlib report-gcc-newlib-nano
report-gcc-newlib: stamps/check-gcc-newlib
	$(srcdir)/scripts/testsuite-filter gcc newlib $(srcdir)/test/allowlist `find build-gcc-newlib-stage2/gcc/testsuite/ -name *.sum |paste -sd "," -`

report-gcc-newlib-nano: stamps/check-gcc-newlib-nano
	$(srcdir)/scripts/testsuite-filter gcc newlib-nano $(srcdir)/test/allowlist `find build-gcc-newlib-stage2/gcc/testsuite/ -name *.sum |paste -sd "," -`

.PHONY: report-gcc-linux
report-gcc-linux: stamps/check-gcc-linux
	$(srcdir)/scripts/testsuite-filter gcc glibc $(srcdir)/test/allowlist `find build-gcc-linux-stage2/gcc/testsuite/ -name *.sum |paste -sd "," -`

.PHONY: report-dhrystone-newlib report-dhrystone-newlib-nano
report-dhrystone-newlib: $(patsubst %,stamps/check-dhrystone-newlib-%,$(NEWLIB_MULTILIB_NAMES))
	if cat $^ | grep -v '^PASS'; then false; else true; fi
report-dhrystone-newlib-nano: $(patsubst %,stamps/check-dhrystone-newlib-nano-%,$(NEWLIB_MULTILIB_NAMES))
	if cat $^ | grep -v '^PASS'; then false; else true; fi

.PHONY: report-dhrystone-linux
report-dhrystone-linux: $(patsubst %,stamps/check-dhrystone-linux-%,$(GLIBC_MULTILIB_NAMES))
	if cat $^ | grep -v '^PASS'; then false; else true; fi

.PHONY: report-binutils-newlib report-binutils-newlib-nano
report-binutils-newlib: stamps/check-binutils-newlib
	$(srcdir)/scripts/testsuite-filter binutils newlib \
	    $(srcdir)/test/allowlist \
	    `find build-binutils-newlib/ -name *.sum |paste -sd "," -`

report-binutils-newlib-nano: stamps/check-binutils-newlib-nano
	$(srcdir)/scripts/testsuite-filter binutils newlib-nano \
	    $(srcdir)/test/allowlist \
	    `find build-binutils-newlib/ -name *.sum |paste -sd "," -`

.PHONY: report-binutils-linux
report-binutils-linux: stamps/check-binutils-linux
	$(srcdir)/scripts/testsuite-filter binutils glibc \
	    $(srcdir)/test/allowlist \
	    `find build-binutils-linux/ -name *.sum |paste -sd "," -`

clean:
	rm -rf build-* stamps install-newlib-nano

.PHONY: report-gdb-newlib report-gdb-newlib-nano
report-gdb-newlib: stamps/check-gdb-newlib
	stat $(patsubst %,$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)) || exit 1
# Fail if there are blank lines in the log file used as input for grep below.
	if grep '^$$' $(patsubst %,$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)); then exit 1; fi
	if find build-gdb-newlib -iname '*.sum' | xargs grep ^FAIL | sort | grep -F -v $(patsubst %,--file=$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)); then false; else true; fi

report-gdb-newlib-nano: stamps/check-gdb-newlib-nano
	stat $(patsubst %,$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)) || exit 1
# Fail if there are blank lines in the log file used as input for grep below.
	if grep '^$$' $(patsubst %,$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)); then exit 1; fi
	if find build-gdb-newlib -iname '*.sum' | xargs grep ^FAIL | sort | grep -F -v $(patsubst %,--file=$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)); then false; else true; fi

.PHONY: report-gdb-linux
report-gdb-linux: stamps/check-gdb-linux
	stat $(patsubst %,$(srcdir)/test/gdb-linux/%.log,$(GLIBC_MULTILIB_NAMES)) || exit 1
# Fail if there are blank lines in the log file used as input for grep below.
	if grep '^$$' $(patsubst %,$(srcdir)/test/gdb-linux/%.log,$(GLIBC_MULTILIB_NAMES)); then exit 1; fi
	if find build-gdb-linux -iname '*.sum' | xargs grep ^FAIL | sort | grep -F -v $(patsubst %,--file=$(srcdir)/test/gdb-linux/%.log,$(GLIBC_MULTILIB_NAMES)); then false; else true; fi

distclean: clean
	rm -rf src

# All of the packages install themselves, so our install target does nothing.
install:

# Rebuilding Makefile.
Makefile: $(srcdir)/Makefile.in config.status
	CONFIG_FILES=$@ CONFIG_HEADERS= $(SHELL) ./config.status

config.status: $(srcdir)/configure
	CONFIG_SHELL="$(SHELL)" $(SHELL) ./config.status --recheck