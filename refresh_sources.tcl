add_files -fileset sources_1 [glob -nocomplain ./src/*.sv ./src/*.v]
add_files -fileset sim_1    [glob -nocomplain ./sim/*.sv ./sim/*.v]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1