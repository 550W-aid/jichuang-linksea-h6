#!/usr/bin/env tclsh

proc usage {} {
    puts "Usage: elinx-server-client.tcl ?--host HOST? ?--port PORT? <command> ?args?"
    puts ""
    puts "Commands:"
    puts "  version"
    puts "  project-exists <path-to-project-file>"
    puts "  project-open <path-to-project-file>"
    puts "  project-close"
    puts "  cmp-start"
    puts "  cmp-stop"
    puts "  cmp-is-running"
    puts "  sim-start ?misc?"
    puts "  sim-stop"
    exit 1
}

proc fail {message} {
    puts stderr $message
    exit 1
}

set host ""
set port ""
set args_copy $argv
set filtered {}

while {[llength $args_copy] > 0} {
    set token [lindex $args_copy 0]
    set args_copy [lrange $args_copy 1 end]
    switch -- $token {
        --host {
            if {[llength $args_copy] == 0} { fail "Missing value for --host" }
            set host [lindex $args_copy 0]
            set args_copy [lrange $args_copy 1 end]
        }
        --port {
            if {[llength $args_copy] == 0} { fail "Missing value for --port" }
            set port [lindex $args_copy 0]
            set args_copy [lrange $args_copy 1 end]
        }
        -h -
        --help {
            usage
        }
        default {
            lappend filtered $token
            foreach item $args_copy {
                lappend filtered $item
            }
            set args_copy {}
        }
    }
}

if {[llength $filtered] == 0} {
    usage
}

if {![info exists env(ELINX_HOME)] || $env(ELINX_HOME) eq ""} {
    set env(ELINX_HOME) "D:/eLinx3.0"
}
if {$port ne ""} {
    set env(QUARTUS_TCL_PORT) $port
}

set client_script [file join $env(ELINX_HOME) bin Passkey bin tcl_client.tcl]
if {![file exists $client_script]} {
    fail "Vendor Tcl client not found at $client_script"
}

source $client_script

if {$host ne ""} {
    q_remote_attach $host 0
} else {
    q_attach 0
}

set command [lindex $filtered 0]
set payload [lrange $filtered 1 end]

proc require_arg {args_list index label} {
    if {[llength $args_list] <= $index} {
        fail "Missing argument: $label"
    }
    return [lindex $args_list $index]
}

set exit_code 0
if {[catch {
    switch -- $command {
        version {
            puts [q_get_version]
        }
        project-exists {
            set path [file normalize [require_arg $payload 0 "path-to-project-file"]]
            puts [q_project_exists $path]
        }
        project-open {
            set path [file normalize [require_arg $payload 0 "path-to-project-file"]]
            puts [q_project_open $path]
        }
        project-close {
            puts [q_project_close]
        }
        cmp-start {
            puts [q_cmp_start]
        }
        cmp-stop {
            puts [q_cmp_stop]
        }
        cmp-is-running {
            puts [q_cmp_is_running]
        }
        sim-start {
            puts [q_sim_start [join $payload " "]]
        }
        sim-stop {
            puts [q_sim_stop]
        }
        default {
            fail "Unsupported command: $command"
        }
    }
} err]} {
    puts stderr $err
    set exit_code 1
}

catch { q_detach }
exit $exit_code
