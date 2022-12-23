# Copyright (C) 2020 Free Software Foundation, Inc.
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

BEGIN {
    # Avoid reading stdin if no files were given on the command line.
    ARGV[ARGC++] = "/dev/null"
}

END {
    if (UNIT_RESULT == "pass")
	print "\tPASSED: sample unit test"
    else if (UNIT_RESULT == "fail")
	print "\tFAILED: sample unit test"
    else if (UNIT_RESULT == "xpass")
	print "\tXPASSED: sample unit test"
    else if (UNIT_RESULT == "xfail")
	print "\tXFAILED: sample unit test"
    else if (UNIT_RESULT == "untested")
	print "\tUNTESTED: sample unit test"
    else if (UNIT_RESULT == "unresolved")
	print "\tUNRESOLVED: sample unit test"
}

# EOF
