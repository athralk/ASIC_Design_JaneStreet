# Load out/eth10t.bit into the Arty over USB (volatile; lost at power-off).
#   source program.tcl
set dir [file dirname [file normalize [info script]]]

open_hw_manager
connect_hw_server
open_hw_target
set device [lindex [get_hw_devices xc7a*] 0]
current_hw_device $device
set_property PROGRAM.FILE $dir/out/eth10t.bit $device
program_hw_devices $device
close_hw_manager
