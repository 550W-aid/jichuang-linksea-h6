project_open hdmi_sdram_1024x600_60Hz -revision hdmi_sdram_1024x600_60Hz
create_timing_netlist -post_map
read_sdc
update_timing_netlist

puts "===== CLOCKS ====="
report_clocks

puts "===== UNCONSTRAINED PATHS ====="
report_ucp

puts "===== EXCEPTIONS ====="
report_exceptions

puts "===== WORST 10 SETUP PATHS ====="
report_timing -npaths 10 -detail full_path

puts "===== WORST 10 RECOVERY/REMOVAL PATHS ====="
report_timing -npaths 10 -detail full_path -recovery
report_timing -npaths 10 -detail full_path -removal

delete_timing_netlist
project_close
