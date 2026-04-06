# ============================================================================
# HomeGuardX v2.0 — Vivado Implementation + Bitstream Script
# Usage: vivado -mode batch -source impl.tcl
# Prerequisite: Run synth.tcl first to generate synth_checkpoint.dcp
# ============================================================================

# Read synthesis checkpoint
open_checkpoint synth_checkpoint.dcp

# ---- Opt Design ----
opt_design -directive Explore

# ---- Place Design ----
place_design -directive Explore

# Reports after placement
report_utilization -file impl_utilization.rpt
report_clock_utilization -file impl_clock_util.rpt

# ---- Physical Optimization ----
phys_opt_design -directive AggressiveExplore

# ---- Route Design ----
route_design -directive Explore

# ---- Post-Route Reports ----
report_timing_summary -file impl_timing.rpt -max_paths 20
report_route_status -file impl_route_status.rpt
report_drc -file impl_drc.rpt
report_power -file impl_power.rpt

# ---- Check Timing ----
set timing_ok [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
if {$timing_ok < 0} {
    puts "WARNING: Negative setup slack ($timing_ok ns) — timing not met!"
} else {
    puts "Timing met. Worst setup slack: $timing_ok ns"
}

# ---- Write Checkpoint ----
write_checkpoint -force impl_checkpoint.dcp

# ---- Generate Bitstream ----
write_bitstream -force HomeGuardX_v2.bit

# ---- Optional: Write debug probes ----
# write_debug_probes -force HomeGuardX_v2.ltx

puts "============================================"
puts "  Implementation + Bitstream complete"
puts "  Bitstream: HomeGuardX_v2.bit"
puts "  Program via: Open Hardware Manager"
puts "============================================"
