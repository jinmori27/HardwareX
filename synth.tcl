# ============================================================================
# HomeGuardX v2.0 — Vivado Synthesis Script
# Usage: vivado -mode batch -source synth.tcl
# ============================================================================

# Project settings
set project_name "HomeGuardX_v2"
set part "xc7a35tcpg236-1"
set top_module "top_level_controller"

# Create in-memory project
create_project -in_memory -part $part

# Add source files
set src_dir "../src"
add_files [glob $src_dir/core/*.v]
add_files [glob $src_dir/security/*.v]
add_files [glob $src_dir/environment/*.v]
add_files [glob $src_dir/io/*.v]

# Add include directory for hmcb_pkg.vh
set_property verilog_define {} [current_fileset]
set_property include_dirs [list $src_dir] [current_fileset]

# Add constraint files
add_files -fileset constrs_1 ../constraints/basys3_pins.xdc
add_files -fileset constrs_1 ../constraints/timing.xdc

# Set top module
set_property top $top_module [current_fileset]

# Run synthesis
synth_design -top $top_module -part $part \
    -flatten_hierarchy rebuilt \
    -directive Default

# Reports
report_utilization -file synth_utilization.rpt
report_timing_summary -file synth_timing.rpt
report_clock_networks -file synth_clocks.rpt

# Write checkpoint
write_checkpoint -force synth_checkpoint.dcp

puts "============================================"
puts "  Synthesis complete: $project_name"
puts "  See synth_utilization.rpt for resource usage"
puts "  See synth_timing.rpt for timing summary"
puts "============================================"
