# Befor running:
# cd project root
# source run_tests.tcl

source refresh_sources.tcl

proc run_tb {tb_name} {
    puts "========================================"
    puts "Running testbench: $tb_name"
    puts "========================================"

    if {[current_sim] ne ""} {
        close_sim
    }

    set_property top $tb_name [get_filesets sim_1]
    update_compile_order -fileset sim_1

    launch_simulation -simset sim_1 -mode behavioral

    run 1us

    close_sim
}

run_tb tb_alu
run_tb tb_regfile

puts "========================================"
puts "All requested testbenches completed."
puts "========================================"