# Non-project Vivado build. From the Vivado Tcl console:
#   cd D:/JaneStreet_Chip/eth10t
#   source build.tcl
# or from a Windows command prompt in that folder:
#   vivado -mode batch -source build.tcl
#
# Arty A7-35T is xc7a35ticsg324-1L. For the A7-100T use xc7a100tcsg324-1.
set part xc7a35ticsg324-1L

set dir [file dirname [file normalize [info script]]]
file mkdir $dir/out

read_verilog [list $dir/top.v $dir/eth10t_arty.v]
read_xdc $dir/arty.xdc

synth_design -top arty_top -part $part
opt_design
place_design
phys_opt_design
route_design

report_utilization    -file $dir/out/utilization.rpt
report_timing_summary -file $dir/out/timing.rpt
write_bitstream -force $dir/out/eth10t.bit

puts "Bitstream: $dir/out/eth10t.bit"
puts "Worst setup slack: [get_property SLACK [get_timing_paths -delay_type max]] ns"
