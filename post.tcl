vsim -L /filespace/j/jlin445/ece551/SAED32_lib -voptargs=+acc work.Segway_tb -t ns

add wave -position insertpoint sim:/Segway_tb/*

add wave -position insertpoint  \
sim:/Segway_tb/iDUT/ptch \
sim:/Segway_tb/iDUT/ptch_rt \
sim:/Segway_tb/iDUT/steer_pot \
sim:/Segway_tb/iDUT/lft_ld \
sim:/Segway_tb/iDUT/rght_ld

add wave -position insertpoint  \
sim:/Segway_tb/iPHYS/theta_platform

run -all