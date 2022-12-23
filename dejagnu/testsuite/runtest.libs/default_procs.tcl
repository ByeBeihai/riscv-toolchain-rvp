# Copyright (C) 1996-2019, 2020 Free Software Foundation, Inc.
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
set sum_file ""
set reboot 0
set errno ""

# this tests a proc for a returned pattern
proc lib_pat_test { cmd arglist pattern } {
    puts "CMD(lib_pat_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 0 } {
	puts "RESULT(lib_pat_test) was: \"${result}\"\
		for pattern \"$pattern\"."
	return [string match $pattern $result]
    } else {
	puts "RESULT(lib_pat_test) was error \"${result}\""
	return -1
    }
}

# this tests a proc for a returned regexp
proc lib_regexp_test { cmd arglist regexp } {
    puts "CMD(lib_regexp_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 0 } {
	puts "RESULT(lib_regexp_test) was: \"${result}\"\
		for regexp \"$regexp\"."
	return [regexp -- $regexp $result]
    } else {
	puts "RESULT(lib_regexp_test) was error \"${result}\""
	return -1
    }
}

# this tests a proc for a returned value
proc lib_ret_test { cmd arglist val } {
    puts "CMD(lib_ret_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 0 } {
	puts "RESULT(lib_ret_test) was: $result"
	return [string equal $result $val]
    } else {
	puts "RESULT(lib_ret_test) was error \"${result}\""
	return -1
    }
}

# this tests a proc for an expected boolean result
proc lib_bool_test { cmd arglist val } {
    puts "CMD(lib_bool_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 0 } {
	puts "RESULT(lib_bool_test) was: \"$result\" expecting $val."
	# the "odd" spacing is used to help make the operator grouping clear
	return [expr {  $val  ?   $result ? 1 : 0   :   $result ? 0 : 1   }]
    } else {
	puts "RESULT(lib_bool_test) was error \"${result}\""
	return -1
    }
}

# this tests that a proc raises an error matching a pattern
proc lib_errpat_test { cmd arglist pattern } {
    puts "CMD(lib_errpat_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 1 } {
	# caught exception code 1 (TCL_ERROR) as expected
	puts "RESULT(lib_errpat_test) was error\
		\"${result}\" for pattern \"$pattern\"."
	if { [string match $pattern $result] } {
	    # the expected error
	    return 1
	} else {
	    # an unexpected error
	    return -1
	}
    } else {
	# no error -> fail
	puts "RESULT(lib_errpat_test) was: \"${result}\"\
		without error; failing."
	return 0
    }
}

# this tests that a proc raises an error matching a regexp
proc lib_errregexp_test { cmd arglist regexp } {
    puts "CMD(lib_errregexp_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 1 } {
	# caught exception code 1 (TCL_ERROR) as expected
	puts "RESULT(lib_errregexp_test) was error\
		\"${result}\" for regexp \"$regexp\"."
	if { [regexp -- $regexp $result] } {
	    # the expected error
	    return 1
	} else {
	    # an unexpected error
	    return -1
	}
    } else {
	# no error -> fail
	puts "RESULT(lib_errregexp_test) was: \"${result}\"\
		without error; failing."
	return 0
    }
}

# this tests that a proc raises an error matching an exact string
proc lib_err_test { cmd arglist val } {
    puts "CMD(lib_err_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 1 } {
	# caught exception code 1 (TCL_ERROR) as expected
	puts "RESULT(lib_err_test) was error: $result"
	if { $result eq $val } {
	    # the expected error
	    return 1
	} else {
	    # an unexpected error
	    return -1
	}
    } else {
	# no error -> fail
	puts "RESULT(lib_err_test) was: \"${result}\"\
		without error; failing."
	return 0
    }
}

# support for testing output procs
proc clear_test_output {} {
    global test_output

    array unset test_output
    array set test_output { error {} log {} tty {} user {} }
}

proc store_test_output { dest argv } {
    global test_output

    set argc [llength $argv]
    for { set argi 0 } { $argi < $argc } { incr argi } {
	set arg [lindex $argv $argi]
	if { $arg eq "--" } {
	    set stri [expr $argi + 1]
	    break
	} elseif { ![string match "-*" $arg] } {
	    set stri $argi
	}
    }
    # the string must be the last argument
    if { $stri != ($argc - 1) } {
	error "bad call: send_${dest} $argv"
    }
    append test_output($dest) [lindex $argv $stri]
}
foreach dest { error log tty user } {
    proc send_${dest} { args } [concat store_test_output $dest {$args}]
}

# this checks output against VAL, which is a list of key-value pairs
#  each key specifies an output channel (from { error log tty user }) and a
#  matching mode (from { "", pat, re }) separated by "_" unless mode is ""
proc lib_output_test { cmd arglist val } {
    global test_output

    puts "CMD(lib_output_test) is: $cmd $arglist"
    clear_test_output
    if { ([llength $val] % 2) != 0 } {
	puts "ERROR(lib_output_test): expected result is invalid"
	return -1
    }
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 0 } {
	puts "RESULT(lib_output_test) was: $result"
	foreach dest { error log tty user } {
	    puts "OUTPUT(lib_output_test/$dest) was: <<$test_output($dest)>>"
	}
    } else {
	puts "RESULT(lib_output_test) was error \"${result}\""
	return -1
    }
    foreach { check expected } $val {
	if { [regexp {(error|log|tty|user)(?:_(pat|re))?} $check\
		  -> dest mode] != 1 } {
	    puts "ERROR(lib_output_test): unknown check token: $check"
	    return -1
	}
	switch -- $mode {
	    "" {
		if { ![string equal $expected $test_output($dest)] } {
		    return 0
		}
	    }
	    pat {
		if { ![string match $expected $test_output($dest)] } {
		    return 0
		}
	    }
	    re {
		if { ![regexp -- $expected $test_output($dest)] } {
		    return 0
		}
	    }
	}
    }
    # if we get here, all checks have passed
    return 1
}

#
# This runs a standard test for a proc. The list is set up as:
# |test proc|proc being tested|args|pattern|message|
# test proc is something like lib_pat_test or lib_ret_test.
#
proc run_tests { tests } {
    foreach test $tests {
	# skip comments in test lists
	if { [lindex $test 0] eq "#" } { continue }
	set result [eval [lrange $test 0 3]]
	switch -- $result {
	    "-1" {
		puts "ERRORED: [lindex $test 4]"
	    }
	    "1" {
		puts "PASSED: [lindex $test 4]"
	    }
	    "0" {
		puts "FAILED: [lindex $test 4]"
	    }
	    default {
		puts "BAD VALUE: [lindex $test 4]"
	    }
	}
    }
}

proc pass { msg } {
    puts "PASSED: $msg"
}

proc fail { msg } {
    puts "FAILED: $msg"
}

proc perror { msg } {
    global errno
    puts "ERRORED: $msg"
    set errno $msg
}

proc warning { msg } {
    global errno
    puts "WARNED: $msg"
    set errno $msg
}

proc untested { msg } {
    puts "NOTTESTED: $msg"
}

proc unsupported { msg } {
    puts "NOTSUPPORTED: $msg"
}
proc verbose { args } {
    puts [lindex $args 0]
}
