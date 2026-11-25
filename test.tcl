set project_dir [file dirname [file normalize [info script]]]
#for .do script 's filelist

proc compile_files {args} {
      global project_dir
      #for .do script 's filelist
      vlog $project_dir/testbench/define.svh
      vlog $project_dir/rtl_src/rst_synch.sv
      vlog $project_dir/rtl_src/inert_intf.sv
      vlog $project_dir/rtl_src/SPI_main.sv
      vlog $project_dir/rtl_src/inertial_integrator.sv
      vlog $project_dir/rtl_src/SPI_NEMO1.sv
      vlog $project_dir/rtl_src/piezo_drv.sv
      vlog $project_dir/rtl_src/A2D_Intf.sv
      vlog $project_dir/rtl_src/UART_rx.sv
      vlog $project_dir/rtl_src/steer_en_SM.sv
      vlog $project_dir/rtl_src/mtr_drv.sv
      vlog $project_dir/rtl_src/SegwayMath.sv
      vlog $project_dir/rtl_src/steer_en_tb.sv
      vlog $project_dir/rtl_src/up_dwn_cnt4.sv
      vlog $project_dir/rtl_src/steer_en.sv
      vlog $project_dir/rtl_src/SPI_ADC128S.sv
      vlog $project_dir/rtl_src/PB_release.sv
      vlog $project_dir/rtl_src/Segway_tb.sv
      vlog $project_dir/rtl_src/ADC128S_FC.sv
      vlog $project_dir/rtl_src/balance_cntrl.sv
      vlog $project_dir/rtl_src/PWM11.sv
      vlog $project_dir/rtl_src/Auth_blk.sv
      vlog $project_dir/rtl_src/PID_Math.sv
      vlog $project_dir/rtl_src/PID.sv
      vlog $project_dir/rtl_src/SegwayModel.sv
      vlog $project_dir/rtl_src/UART_tx.sv
      vlog $project_dir/rtl_src/Segway.sv
      vlog $project_dir/testbench/tb_tasks.sv
      vlog +incdir+$project_dir/testbench $project_dir/testbench/Segway_tb_seq.sv
}

set fp [open "$project_dir/testbench/define.svh" w]
puts $fp "`define TP1"
close $fp

vlib  work
vmap work work
compile_files

vsim -t 1ns work.Segway_tb_seq -voptargs=+acc

add wave -position insertpoint sim:/Segway_tb_seq/Seg_intf/*
add wave -position insertpoint sim:/Segway_tb_seq/iPHYS/theta_*
add wave -position insertpoint sim:/Segway_tb_seq/iDUT/ptch
add wave -position insertpoint sim:/Segway_tb_seq/iDUT/iBUZZ/cmd
add wave -position insertpoint sim:/Segway_tb_seq/*
add wave -position insertpoint sim:/Segway_tb_seq/iDUT/iBUZZ/too_fast
add wave -position insertpoint sim:/Segway_tb_seq/iDUT/iBUZZ/en_steer
add wave -position insertpoint sim:/Segway_tb_seq/iDUT/iBUZZ/batt_low
add wave -position insertpoint sim:/Segway_tb_seq/iDUT/iAuth/cstate

run -all
dataset save sim wave1.wlf
write format wave wave1.do

set fp [open "$project_dir/testbench/define.svh" w]
puts $fp "`define TP2"
close $fp

compile_files
restart
run -all
dataset save sim wave2.wlf
write format wave wave2.do

set fp [open "$project_dir/testbench/define.svh" w]
puts $fp "`define TP3"
close $fp

compile_files
restart
run -all
dataset save sim waves3.wlf
write format wave wave3.do

set fp [open "$project_dir/testbench/define.svh" w]
puts $fp "`define TP4"
close $fp

compile_files
restart
run -all
dataset save sim wave4.wlf
write format wave wave4.do

# An overall test that to see the code coverage
set fp [open "$project_dir/testbench/define.svh" w+]
puts $fp "`define TP1 \n `define TP2 \n `define TP3 \n `define TP4"
close $fp

compile_files
restart
run -all
dataset save sim wave5.wlf
write format wave wave5.do