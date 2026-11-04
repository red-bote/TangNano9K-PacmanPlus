# Batch build of the Basys 3 bitstream. Helper of make bitstream, run from /tmp:
#   vivado -mode batch -source build.tcl -tclargs <xpr>

if { [llength $argv] != 1 } {
    puts "ERROR: usage: -tclargs <xpr>"
    exit 2
}
set xpr [file normalize [lindex $argv 0]]

proc write_file { path text } {
    set fh [open $path w]
    fconfigure $fh -translation lf
    puts -nonewline $fh $text
    close $fh
}

# Replace the placeholder Path in the tracked .xpr for the open.
set mtime [file mtime $xpr]
set fh [open $xpr r]
fconfigure $fh -translation lf
set tracked [read $fh]
close $fh
if { ![regsub {(<Project [^>]*Path=")[^"]*"} $tracked "\\1[string map {& \\&} $xpr]\"" local] } {
    puts "ERROR: no Project Path attribute in $xpr"
    exit 2
}
write_file $xpr $local

set progress ""
set rc [catch {
    open_project $xpr
    reset_run synth_1
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    set progress [get_property PROGRESS [get_runs impl_1]]
    close_project
} err]

# Vivado rewrites the .xpr on open and run: restore the tracked text, also on error,
# and its mtime, so make does not rebuild because of the .xpr.
write_file $xpr $tracked
file mtime $xpr $mtime

if { $rc } {
    puts "ERROR: $err"
    exit 1
}
if { $progress ne "100%" } {
    puts "ERROR: implementation/bitstream failed (PROGRESS $progress)"
    exit 1
}
