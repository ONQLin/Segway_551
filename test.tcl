#for .do script 's filelist

proc compile_files {args} {
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/rst_synch.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/inert_intf.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/spi_mnrch.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/inertial_integrator.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/SPI_iNEMO1.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/piezo_drv.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/A2D_Intf.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/uart_rx.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/steer_en_SM.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/mtr_drv.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/SegwayMath.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/steer_en_tb.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/up_dwn_cnt4.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/steer_en.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/SPI_ADC128S.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/PB_release.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/Segway_tb.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/ADC128S_FC.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/balance_ctrl.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/PWM11.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/Auth_blk.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/PID.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/SegwayModel.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/uart_tx.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/rtl_src/Segway.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/testbench/tb_tasks.sv
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/testbench/define.svh
      vlog /filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/testbench/Segway_tb_seq.sv
}

set fp [open "/filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/testbench/define.svh" w]
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
#write format wave wave1.do

set fp [open "/filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/testbench/define.svh" w]
puts $fp "`define TP2"
close $fp

compile_files
restart
run -all
dataset save sim wave2.wlf

set fp [open "/filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/testbench/define.svh" w]
puts $fp "`define TP3"
close $fp

compile_files
restart
run -all
dataset save sim waves3.wlf

set fp [open "/filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/testbench/define.svh" w]
puts $fp "`define TP4"
close $fp

compile_files
restart
run -all
dataset save sim wave4.wlf

# An overall test that to see the code coverage
set fp [open "/filespace/j/jlin445/win/desktop/Segway_553-main/Segway_553-main/testbench/define.svh" w+]
puts $fp "`define TP1 \n `define TP2 \n `define TP3 \n `define TP4"
close $fp

compile_files
restart
run -all
dataset save sim wave5.wlf