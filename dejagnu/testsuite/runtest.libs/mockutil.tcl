# Copyright (C) 2019 Free Software Foundation, Inc.
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

# This file was written by Jacob Bachmeyer.

# This library provides convenience procedures for running isolated tests
# of DejaGnu procedures in a slave interpreter.  These are designed to be
# run in the child process used by the DejaGnu library tests.

proc strip_comment_lines { text } {
    regsub -all -- {\n[[:space:]]*#[^\r\n]*[\r\n]+} $text "\n"
}

proc create_test_interpreter { name opts } {
    array set opt {
	copy_arrays {} copy_procs {} copy_vars {}
	link_channels {} link_procs {} shim_procs {} mocks {} vars {}
    }
    array set opt [strip_comment_lines $opts]

    interp create -safe -- $name
    foreach array $opt(copy_arrays) { # inlined due to upvar
	if { [llength $array] == 2 } {
	    upvar [lindex $array 1] src_array
	} elseif { [llength $array] == 1 } {
	    upvar [lindex $array 0] src_array
	} else {
	    error "bogus copy_arrays directive: $array"
	}
	$name eval array set [list [lindex $array 0] [array get src_array]]
    }
    foreach proc $opt(copy_procs) { # inlined due to uplevel
	# proc reconstruction adapted from Tcl info(n) manpage
	set argspec [list]
	foreach arg [uplevel info args $proc] {
	    if { [uplevel info default $proc $arg value] } {
		lappend argspec [list $arg $value]
	    } else {
		lappend argspec [list $arg]
	    }
	}
	$name eval proc $proc [list $argspec] [list [uplevel info body $proc]]
    }
    foreach var $opt(copy_vars) { # inlined due to upvar
	if { [llength $var] == 2 } {
	    upvar [lindex $var 1] src_var
	} elseif { [llength $var] == 1 } {
	    upvar [lindex $var 0] src_var
	} else {
	    error "bogus copy_vars directive: $var"
	}
	$name eval set [list [lindex $var 0] $src_var]
    }
    foreach {varname var} $opt(vars) {
	$name eval set [list $varname $var]
    }
    foreach {mockname arglist retexpr} $opt(mocks) {
	establish_mock $name $mockname $arglist $retexpr
    }
    foreach chan $opt(link_channels)	{ interp share {} $chan $name }
    foreach link $opt(link_procs)	{ establish_link $name $link }
    foreach shim $opt(shim_procs)	{ establish_shim $name $shim }
    return $name
}
proc copy_array_to_test_interpreter { sicmd dest {src {}} } {
    if { $src eq {} } { set src $dest }
    upvar $src src_array
    $sicmd eval array set [list $dest [array get src_array]]
}
proc delete_test_interpreter { name } {
    interp delete $name
}

proc reset_mock_trace {} {
    global mock_call_trace
    set mock_call_trace [list]
}
proc dump_mock_trace {} {
    global mock_call_trace
    puts "<<< mocked calls recorded"
    foreach cell $mock_call_trace {
	puts "  [lindex $cell 0]"
	if { [llength $cell] > 1 } {
	    puts "    -> [lindex $cell 1]"
	}
    }
    puts ">>> mocked calls recorded"
}
proc get_mock_trace {} {
    global mock_call_trace
    return $mock_call_trace
}
proc find_mock_calls { prefix } {
    global mock_call_trace
    set result [list]
    foreach cell $mock_call_trace {
	if { [string match "${prefix}*" [lindex $cell 0]] } {
	    lappend result $cell
	}
    }
    return $result
}

proc relay_link_call { name args } {
    eval [list $name] $args
}
proc establish_link { sicmd name } {
    $sicmd alias $name relay_link_call $name
}

proc record_mock_call { name args } {
    global mock_call_trace
    lappend mock_call_trace [list [linsert $args 0 $name]]
    return
}
proc establish_mock_log_alias { sicmd name } {
    $sicmd alias logcall_$name record_mock_call $name
}
proc establish_mock { sicmd name arglist retexpr } {
    establish_mock_log_alias $sicmd $name

    set sargl [list]
    foreach arg $arglist { lappend sargl [format {$%s} $arg] }

    if { [lindex $arglist end] eq "args" } {
	set log_call \
	    "eval \[list logcall_$name [join [lrange $sargl 0 end-1]]\] \$args"
    } else {
	set log_call \
	    "logcall_$name [join $sargl]"
    }

    $sicmd eval [subst -nocommands {
	proc $name {$arglist} {
	    $log_call
	    return $retexpr
	}
    }]
}

proc relay_shim_call { name args } {
    global mock_call_trace
    set retval [eval [list $name] $args]
    lappend mock_call_trace [list [linsert $args 0 $name] [list $retval]]
    return $retval
}
proc establish_shim { sicmd name } {
    $sicmd alias $name relay_shim_call $name
}

proc match_argpat { argpat call } {
    set result 1
    foreach {pos qre} $argpat {
	set qre [regsub -all {\M\s+(?=[^*+?\s])} $qre {\s+}]
	set qre [regsub -all {([*+?])\s+(?=[^*+?\s])} $qre {\1\s+} ]
	set out [lindex $call 0 $pos]
	verbose "matching: ^$qre$"
	verbose " against:  $out"
	if { ![regexp "^$qre$" $out] } { set result 0 }
    }
    return $result
}

proc test_proc_with_mocks { name sicmd code args } {
    array set opt {
	check_calls {}
    }
    foreach { key value } $args {
	if { ![info exists opt($key)] } {
	    error "test_proc_with_mocks: unknown option $key"
	}
	set opt($key) [strip_comment_lines $value]
    }

    verbose "--------  begin test: $name"
    reset_mock_trace
    $sicmd eval $code
    dump_mock_trace

    set result pass
    foreach { prefix callpos argpat } $opt(check_calls) {
	set calls [find_mock_calls $prefix]

	verbose "checking: \[$callpos\] $prefix"
	if { $callpos eq "*" } {
	    # succeed if any call matches both prefix and argpat
	    set innerresult fail
	    foreach { call } $calls {
		verbose "    step: [lindex $call 0]"
		if { [match_argpat $argpat $call] } {
		    set innerresult pass
		    break
		}
	    }
	    if { $innerresult ne "pass" } {
		verbose "  failed!"
		set result fail
	    }
	} elseif { $callpos eq "!" } {
	    # succeed if no calls match prefix
	    if { [llength $calls] != 0 } {
		verbose "  failed!"
		set result fail
	    }
	} elseif { $callpos eq "U" } {
	    # prefix selects one unique call
	    if { [llength $calls] != 1 } {
		error "expected unique call"
		return
	    }
	    if { ![match_argpat $argpat [lindex $calls 0]] } {
		verbose "  failed!"
		set result fail
	    }
	} elseif { [llength $calls] > $callpos } {
	    if { ![match_argpat $argpat [lindex $calls $callpos]] } {
		verbose "  failed!"
		set result fail
	    }
	} else {
	    error "failed to select trace record"
	    return
	}
    }

    $result $name
    verbose "--------    end test: $name"
}


#EOF
