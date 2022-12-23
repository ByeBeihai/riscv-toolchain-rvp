# Copyright (C) 1992-2019, 2020 Free Software Foundation, Inc.
#
# This file is part of DejaGnu.
#
# DejaGnu is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# DejaGnu is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with DejaGnu; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1301, USA.

# Process this file with automake to generate Makefile.in

AUTOMAKE_OPTIONS = dejagnu
export DEJAGNU

# record all files in the distribution tarball as owned by root
TAR_OPTIONS = --format=v7 --owner=0 --group=0
export TAR_OPTIONS

EXTRA_DIST = ChangeLog-1992 MAINTAINERS dejagnu runtest \
	$(pkgdata_DATA) $(config_DATA) $(baseboard_DATA) \
	$(commands_DATA) $(TESTSUITE_FILES) $(TEXINFO_TEX)\
	$(CONTRIB)

CLEANFILES = dbg.log nested-init.exp pr48155-init.exp

clean-local: clean-local-check
.PHONY: clean-local-check
clean-local-check:
	-rm -rf testsuite/launcher.all/command/bin
	-rm -rf testsuite/launcher.all/command/share
	-rm -rf testsuite/report-card.all/onetest
	-rm -rf testsuite/report-card.all/passes

# Give a reassuring message so that users know the "build" worked.
all-local:
	@echo "Done. Now run 'make install'."

bin_SCRIPTS = dejagnu runtest
include_HEADERS = dejagnu.h

pkgdata_DATA = \
  stub-loader.c \
  testglue.c \
  runtest.exp \
  lib/debugger.exp \
  lib/dejagnu.exp \
  lib/dg.exp \
  lib/dmucs.exp \
  lib/framework.exp \
  lib/ftp.exp \
  lib/kermit.exp \
  lib/libgloss.exp \
  lib/remote.exp \
  lib/rlogin.exp \
  lib/rsh.exp \
  lib/ssh.exp \
  lib/standard.exp \
  lib/target.exp \
  lib/targetdb.exp \
  lib/telnet.exp \
  lib/tip.exp \
  lib/utils.exp

commandsdir = $(pkgdatadir)/commands
commands_DATA = \
	commands/help.sh \
	commands/report-card.awk

configdir = $(pkgdatadir)/config
config_DATA = \
	config/README \
	config/adb.exp \
	config/aarch64-fv8.exp \
	config/default.exp \
	config/gdb-comm.exp \
	config/gdb_stub.exp \
	config/sid.exp \
	config/sim.exp \
	config/unix.exp \
	config/vxworks.exp

baseboarddir = $(pkgdatadir)/baseboards
baseboard_DATA = \
	baseboards/README \
	baseboards/aarch64-sim.exp \
	baseboards/am33_2.0-libremote.exp \
	baseboards/androideabi.exp \
	baseboards/arm-ice.exp \
	baseboards/arm-sid.exp \
	baseboards/arm-sim.exp \
	baseboards/basic-sid.exp \
	baseboards/basic-sim.exp \
	baseboards/cris-sim.exp \
	baseboards/d30v-sim.exp \
	baseboards/fr30-sim.exp \
	baseboards/frv-sim.exp \
	baseboards/gdbserver-sample.exp \
	baseboards/generic-sim.exp \
	baseboards/i386-sid.exp \
	baseboards/iq2000-sim.exp \
	baseboards/jmr3904-sim.exp \
	baseboards/linux-gdbserver.exp \
	baseboards/linux-libremote.exp \
	baseboards/m68k-sid.exp \
	baseboards/mcore-moto-sim.exp \
	baseboards/mcore-sim.exp \
	baseboards/mips-lnews-sim.exp \
	baseboards/mips-lsi-sim.exp \
	baseboards/mips-sim-idt32.exp \
	baseboards/mips-sim-idt64.exp \
	baseboards/mips-sim-mti32.exp \
	baseboards/mips-sim-mti64.exp \
	baseboards/mips-sim-mti64_64.exp \
	baseboards/mips-sim-mti64_n32.exp \
	baseboards/mips-sim-sde32.exp \
	baseboards/mips-sim-sde64.exp \
	baseboards/mips-sim.exp \
	baseboards/mmixware-sim.exp \
	baseboards/mn10200-sim.exp \
	baseboards/mn10300-sim.exp \
	baseboards/moxie-sim.exp \
	baseboards/msp430-sim.exp \
	baseboards/mt-sid.exp \
	baseboards/multi-sim.exp \
	baseboards/pi.exp \
	baseboards/powerpc-sim.exp \
	baseboards/powerpcle-sim.exp \
	baseboards/pru-sim.exp \
	baseboards/qemu.exp \
	baseboards/riscv-sim.exp \
	baseboards/rx-sim.exp \
	baseboards/sh-sid.exp \
	baseboards/sh-sim.exp \
	baseboards/sparc-sim.exp \
	baseboards/sparc64-sim.exp \
	baseboards/sparclite-sim-le.exp \
	baseboards/sparclite-sim.exp \
	baseboards/tx39-sim.exp \
	baseboards/unix.exp \
	baseboards/v850-sim.exp \
	baseboards/visium-sim.exp \
	baseboards/vr4100-sim.exp \
	baseboards/vr4111-sim.exp \
	baseboards/vr4300-sim.exp \
	baseboards/xtensa-sim.exp

djlibexecdir = $(pkgdatadir)/libexec
djlibexec_SCRIPTS = config.guess

# Contributed scripts, etc.

CONTRIB = contrib/sum2junit.sh \
	contrib/mysql/create-db.sql contrib/mysql/importxml.sh \
	contrib/mysql/make-datafile.sh contrib/mysql/plot.sh \
	contrib/mysql/README contrib/mysql/sum2xml.sh \
	contrib/dejagnu.py

# Testsuite.

TESTSUITE_FILES = \
	testsuite/launcher.all/command.exp \
	testsuite/launcher.all/command/commands/bar-baz.awk \
	testsuite/launcher.all/command/commands/bar.awk \
	testsuite/launcher.all/command/commands/bar.sh \
	testsuite/launcher.all/command/commands/baz-quux.gawk \
	testsuite/launcher.all/command/commands/foo.sh \
	testsuite/launcher.all/command/commands/foo.tcl \
	testsuite/launcher.all/help.exp \
	testsuite/launcher.all/interp.exp \
	testsuite/launcher.all/verbose.exp \
	testsuite/report-card.all/onetest.exp \
	testsuite/report-card.all/passes.exp \
	testsuite/runtest.libs/topdir/subdir1/subsubdir1/subsubfile1 \
	testsuite/runtest.libs/topdir/subdir1/subfile1 \
	testsuite/runtest.libs/topdir/subdir1/subfile2 \
	testsuite/runtest.libs/topdir/subdir2/subfile2 \
	testsuite/runtest.libs/libs.exp \
	testsuite/runtest.libs/default_procs.tcl \
	testsuite/runtest.libs/mockutil.tcl \
	testsuite/runtest.libs/clone_output.test \
	testsuite/runtest.libs/config.test \
	testsuite/runtest.libs/remote.test \
	testsuite/runtest.libs/target.test \
	testsuite/runtest.libs/testcase_group.test \
	testsuite/runtest.libs/testsuite_can.test \
	testsuite/runtest.libs/testsuite_file.test \
	testsuite/runtest.libs/utils.test \
	testsuite/runtest.main/error.exp \
	testsuite/runtest.main/nested/testsuite/error.test/error-al-dbz.exp \
	testsuite/runtest.main/nested/testsuite/error.test/error-dbz.exp \
	testsuite/runtest.main/nested/testsuite/error.test/error-undef.exp \
	testsuite/runtest.main/nested/testsuite/error.test/simple.exp \
	testsuite/runtest.main/options.exp \
	testsuite/runtest.main/nested/testsuite/null.test/null.exp \
	testsuite/runtest.main/stats.exp \
	testsuite/runtest.main/nested/testsuite/stat.test/stats-sub.exp \
	testsuite/runtest.main/nested/testsuite/stat.test/unit-sub.awk \
	testsuite/runtest.main/nested/testsuite/stat.test/unit-sub.exp \
	testsuite/runtest.main/pr42399.exp \
	testsuite/runtest.main/nested/testsuite/bug.test/pr42399.awk \
	testsuite/runtest.main/nested/testsuite/bug.test/pr42399-sub.exp \
	testsuite/runtest.main/pr48155-csh.sh \
	testsuite/runtest.main/pr48155.exp \
	testsuite/lib/bohman_ssd.exp \
	testsuite/lib/launcher.exp \
	testsuite/lib/libdejagnu.exp \
	testsuite/lib/libsup.exp \
	testsuite/lib/report-card.exp \
	testsuite/lib/runtest.exp \
	testsuite/lib/util-defs.exp \
	testsuite/libdejagnu/tunit.exp

DEJATOOL = launcher libdejagnu report-card runtest

# We override runtest so that the testsuite is run with this version
# of DejaGnu instead of an installed version.
RUNTEST = ${top_srcdir}/runtest

AM_CXXFLAGS = -I$(top_srcdir) -g
check_PROGRAMS = unit
unit_SOURCES = testsuite/libdejagnu/unit.cc

# Documentation.

TEXINFO_TEX = doc/texinfo.tex
dist_man_MANS = doc/dejagnu.1 \
	doc/dejagnu-help.1 \
	doc/dejagnu-report-card.1 \
	doc/runtest.1
info_TEXINFOS = doc/dejagnu.texi
doc_dejagnu_TEXINFOS = doc/fdl.texi

pip-install:
	pip3 install --upgrade -e $(top_srcdir)
