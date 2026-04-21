if {$argc < 6} {
    puts stderr "usage: run_ooc_signoff.tcl <repo_root> <top_name> <filelist> <out_dir> <part_name> <clock_period>"
    exit 2
}

set repo_root    [file normalize [lindex $argv 0]]
set top_name     [lindex $argv 1]
set filelist_arg [lindex $argv 2]
set out_dir      [file normalize [lindex $argv 3]]
set part_name    [lindex $argv 4]
set clock_period [lindex $argv 5]

proc resolve_path {repo_root raw_path} {
    if {[file pathtype $raw_path] eq "absolute"} {
        return [file normalize $raw_path]
    }
    return [file normalize [file join $repo_root $raw_path]]
}

proc load_filelist {repo_root filelist_path} {
    set rtl_files {}
    set fp [open $filelist_path r]
    while {[gets $fp line] >= 0} {
        set trimmed [string trim $line]
        if {$trimmed eq ""} {
            continue
        }
        if {[string match "#*" $trimmed]} {
            continue
        }
        lappend rtl_files [resolve_path $repo_root $trimmed]
    }
    close $fp
    return $rtl_files
}

proc write_status {out_dir status message} {
    set fp [open [file join $out_dir "run_status.txt"] w]
    puts $fp "status=$status"
    puts $fp "message=$message"
    close $fp
}

file mkdir $out_dir
set filelist_path [resolve_path $repo_root $filelist_arg]
set rtl_files [load_filelist $repo_root $filelist_path]

if {[llength $rtl_files] == 0} {
    write_status $out_dir "FAIL" "empty file list"
    puts stderr "empty file list: $filelist_path"
    exit 3
}

set rc [catch {
    foreach rtl_file $rtl_files {
        read_verilog $rtl_file
    }

    synth_design -top $top_name -part $part_name -mode out_of_context
    create_clock -name clk -period $clock_period [get_ports clk]

    opt_design
    place_design
    phys_opt_design
    route_design

    report_timing_summary -delay_type min_max -report_unconstrained -max_paths 20 \
        -file [file join $out_dir "timing_summary.rpt"]
    report_timing -delay_type max -max_paths 20 \
        -file [file join $out_dir "timing_setup.rpt"]
    report_timing -delay_type min -max_paths 20 \
        -file [file join $out_dir "timing_hold.rpt"]
    report_utilization -file [file join $out_dir "utilization.rpt"]
    report_clock_utilization -file [file join $out_dir "clock_utilization.rpt"]
    write_checkpoint -force [file join $out_dir "post_route.dcp"]

    write_status $out_dir "PASS" "implementation completed"
} result options]

if {$rc != 0} {
    write_status $out_dir "FAIL" $result
    puts stderr $result
    exit 1
}

exit 0
