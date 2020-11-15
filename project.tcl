set origin_dir "."

create_project -force ublaze_mem_and_int ./ublaze_mem_and_int -part xc7k325tffg900-2

set_property board_part digilentinc.com:genesys2:part0:1.1 [current_project]
set_property target_language Verilog [current_project]

create_bd_design "system"

# ################################
#             MIG
# ################################
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.2 mig_7series_0
endgroup

# Add and connect the DDR port
apply_bd_automation -rule xilinx.com:bd_rule:mig_7series -config {Board_Interface "ddr3_sdram" }  [get_bd_cells mig_7series_0]

# Add and connect the reset port (active low)
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( Reset ) } Manual_Source {New External Port (ACTIVE_LOW)}}  [get_bd_pins mig_7series_0/sys_rst]


# ##############################
#          Microblaze
# ##############################

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0
endgroup

apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config { axi_intc {1} axi_periph {Enabled} cache {8KB} clk {/mig_7series_0/ui_clk (100 MHz)} cores {1} debug_module {Debug Only} ecc {None} local_mem {64KB} preset {None}}  [get_bd_cells microblaze_0]

startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/mig_7series_0/ui_clk (100 MHz)} Clk_slave {/mig_7series_0/ui_clk (100 MHz)} Clk_xbar {/mig_7series_0/ui_clk (100 MHz)} Master {/microblaze_0/M_AXI_DC} Slave {/microblaze_0_axi_intc/s_axi} ddr_seg {Auto} intc_ip {/microblaze_0_axi_periph} master_apm {0}}  [get_bd_intf_pins microblaze_0/M_AXI_DC]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/mig_7series_0/ui_clk (100 MHz)} Clk_slave {/mig_7series_0/ui_clk (100 MHz)} Clk_xbar {/mig_7series_0/ui_clk (100 MHz)} Master {/microblaze_0/M_AXI_IC} Slave {/microblaze_0_axi_intc/s_axi} ddr_seg {Auto} intc_ip {/microblaze_0_axi_periph} master_apm {0}}  [get_bd_intf_pins microblaze_0/M_AXI_IC]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/mig_7series_0/ui_clk (100 MHz)} Clk_slave {/mig_7series_0/ui_clk (100 MHz)} Clk_xbar {/mig_7series_0/ui_clk (100 MHz)} Master {/microblaze_0 (Periph)} Slave {/mig_7series_0/S_AXI} ddr_seg {Auto} intc_ip {/microblaze_0_axi_periph} master_apm {0}}  [get_bd_intf_pins mig_7series_0/S_AXI]
endgroup


# ##############################
#  AXI BRAM Controller (cached) 
# ##############################

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
endgroup

startgroup
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA]

apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTB]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/mig_7series_0/ui_clk (100 MHz)} Clk_slave {Auto} Clk_xbar {/mig_7series_0/ui_clk (100 MHz)} Master {/microblaze_0 (Cached)} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {/microblaze_0_axi_periph} master_apm {0}}  [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
endgroup


# ##############################
#         UART Lite
# ##############################

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0
endgroup

set_property name UART [get_bd_cells axi_uartlite_0]

set_property -dict [list CONFIG.C_BAUDRATE {115200} CONFIG.UARTLITE_BOARD_INTERFACE {usb_uart}] [get_bd_cells UART]

startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/mig_7series_0/ui_clk (100 MHz)} Clk_slave {Auto} Clk_xbar {/mig_7series_0/ui_clk (100 MHz)} Master {/microblaze_0 (Periph)} Slave {/UART/S_AXI} ddr_seg {Auto} intc_ip {/microblaze_0_axi_periph} master_apm {0}}  [get_bd_intf_pins UART/S_AXI]

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {usb_uart ( USB UART ) } Manual_Source {Auto}}  [get_bd_intf_pins UART/UART]
endgroup

connect_bd_net [get_bd_pins UART/interrupt] [get_bd_pins microblaze_0_xlconcat/In0]



# ##############################
#        AXI GPIO (leds)
# ##############################

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
endgroup

set_property name GPIO_LEDS [get_bd_cells axi_gpio_0]

set_property -dict [list CONFIG.C_GPIO_WIDTH {8} CONFIG.C_INTERRUPT_PRESENT {0} CONFIG.C_ALL_OUTPUTS {1}] [get_bd_cells GPIO_LEDS]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/mig_7series_0/ui_clk (100 MHz)} Clk_slave {Auto} Clk_xbar {/mig_7series_0/ui_clk (100 MHz)} Master {/microblaze_0 (Periph)} Slave {/GPIO_LEDS/S_AXI} ddr_seg {Auto} intc_ip {/microblaze_0_axi_periph} master_apm {0}}  [get_bd_intf_pins GPIO_LEDS/S_AXI]


create_bd_port -dir O -from 7 -to 0 LEDS

startgroup
connect_bd_net [get_bd_ports LEDS] [get_bd_pins GPIO_LEDS/gpio_io_o]
endgroup

# ##############################
#    AXI GPIO (Sw and buttons)
# ##############################

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
endgroup

set_property name GPIO_SW_BTNS [get_bd_cells axi_gpio_0]

set_property -dict [list CONFIG.C_GPIO_WIDTH {8} CONFIG.C_GPIO2_WIDTH {5} CONFIG.C_IS_DUAL {1} CONFIG.C_ALL_INPUTS {1} CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_INTERRUPT_PRESENT {1} CONFIG.GPIO_BOARD_INTERFACE {dip_switches_8bits} CONFIG.GPIO2_BOARD_INTERFACE {push_buttons_5bits}] [get_bd_cells GPIO_SW_BTNS]

startgroup
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {dip_switches_8bits ( 8 Switches ) } Manual_Source {Auto}}  [get_bd_intf_pins GPIO_SW_BTNS/GPIO]

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {push_buttons_5bits ( 5 Push Buttons ) } Manual_Source {Auto}}  [get_bd_intf_pins GPIO_SW_BTNS/GPIO2]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/mig_7series_0/ui_clk (100 MHz)} Clk_slave {Auto} Clk_xbar {/mig_7series_0/ui_clk (100 MHz)} Master {/microblaze_0 (Periph)} Slave {/GPIO_SW_BTNS/S_AXI} ddr_seg {Auto} intc_ip {/microblaze_0_axi_periph} master_apm {0}}  [get_bd_intf_pins GPIO_SW_BTNS/S_AXI]
endgroup

connect_bd_net [get_bd_pins GPIO_SW_BTNS/ip2intc_irpt] [get_bd_pins microblaze_0_xlconcat/In1]


# ##############################
#          Grouping
# ##############################

group_bd_cells PROCESSOR [get_bd_cells axi_bram_ctrl_0] [get_bd_cells rst_mig_7series_0_100M] [get_bd_cells axi_bram_ctrl_0_bram] [get_bd_cells mdm_1] [get_bd_cells microblaze_0_axi_intc] [get_bd_cells microblaze_0] [get_bd_cells microblaze_0_xlconcat] [get_bd_cells microblaze_0_axi_periph] [get_bd_cells microblaze_0_local_memory]

group_bd_cells PERIPHERALS [get_bd_cells GPIO_SW_BTNS] [get_bd_cells UART] [get_bd_cells GPIO_LEDS] [get_bd_cells mig_7series_0]

# ##############################
#           Renaming
# ##############################

# set_property name M_AXI_MIG [get_bd_intf_pins PROCESSOR/M01_AXI]
# set_property name M_AXI_UART [get_bd_intf_pins PROCESSOR/M02_AXI]
# set_property name M_AXI_GPIO_LEDS [get_bd_intf_pins PROCESSOR/M04_AXI]
# set_property name M_AXI_GPIO_SW_BTNS [get_bd_intf_pins PROCESSOR/M05_AXI]

# set_property name S_AXI_MIG [get_bd_intf_pins PERIPHERALS/S_AXI3]
# set_property name S_AXI_UART [get_bd_intf_pins PERIPHERALS/S_AXI1]
# set_property name S_AXI_GPIO_LEDS [get_bd_intf_pins PERIPHERALS/S_AXI2]
# set_property name S_AXI_GPIO_SW_BTNS [get_bd_intf_pins PERIPHERALS/S_AXI]

# regenerate_bd_layout



# ################################################################
#
# ################################################################

set design_name [get_bd_designs]
make_wrapper -files [get_files $design_name.bd] -top -import

add_files -fileset constrs_1 -norecurse ./ports.xdc
import_files -fileset constrs_1 ./ports.xdc



#
# 
#


launch_runs synth_1 -jobs 32
wait_on_run synth_1

launch_runs impl_1 -jobs 32
wait_on_run impl_1

launch_runs impl_1 -to_step write_bitstream -jobs 32
wait_on_run impl_1

set_property pfm_name {} [get_files -all {./ublaze_mem_and_int/ublaze_mem_and_int.srcs/sources_1/bd/system/system.bd}]

write_hw_platform -fixed -include_bit -force -file system_hw.xsa

start_gui
