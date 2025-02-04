if {[is_project_open]} {
	set project_name $::quartus(project)
	if {[string compare $project_name "generate_sim_example_design"] != 0} {
		post_message -type error "Invalid project \"$project_name\""
		post_message -type error "In order to generate the simulation example design,"
		post_message -type error "please close the current project \"$project_name\""
		post_message -type error "and open the project \"generate_sim_example_design\""
		post_message -type error "in the directory TEST_DDR3_example_design/simulation/"
		return 1
	}
}
set variant_name TEST_DDR3_example_sim
set arg_list [list]
puts "Generating VHDL example design"
set hdl_language vhdl
set hdl_ext vhd
lappend arg_list "--file-set=SIM_VHDL"
lappend arg_list "--system-info=DEVICE_FAMILY=CYCLONEV"
lappend arg_list "--output-name=${variant_name}"
lappend arg_list "--output-dir=${hdl_language}"
lappend arg_list "--report-file=spd:[file join ${hdl_language} ${variant_name}.spd]"
lappend arg_list "--component-param=TG_NUM_DRIVER_LOOP=1"
lappend arg_list "--component-param=ABSTRACT_REAL_COMPARE_TEST=false"
lappend arg_list "--component-param=ABS_RAM_MEM_INIT_FILENAME=meminit"
lappend arg_list "--component-param=ACV_PHY_CLK_ADD_FR_PHASE=0.0"
lappend arg_list "--component-param=AC_PACKAGE_DESKEW=false"
lappend arg_list "--component-param=AC_ROM_USER_ADD_0=0_0000_0000_0000"
lappend arg_list "--component-param=AC_ROM_USER_ADD_1=0_0000_0000_1000"
lappend arg_list "--component-param=ADDR_ORDER=0"
lappend arg_list "--component-param=ADD_EFFICIENCY_MONITOR=false"
lappend arg_list "--component-param=ADD_EXTERNAL_SEQ_DEBUG_NIOS=false"
lappend arg_list "--component-param=ADVANCED_CK_PHASES=false"
lappend arg_list "--component-param=ADVERTIZE_SEQUENCER_SW_BUILD_FILES=false"
lappend arg_list "--component-param=AFI_DEBUG_INFO_WIDTH=32"
lappend arg_list "--component-param=ALTMEMPHY_COMPATIBLE_MODE=false"
lappend arg_list "--component-param=AP_MODE=false"
lappend arg_list "--component-param=AP_MODE_EN=0"
lappend arg_list "--component-param=AUTO_PD_CYCLES=0"
lappend arg_list "--component-param=AUTO_POWERDN_EN=false"
lappend arg_list "--component-param=AVL_DATA_WIDTH_PORT=32,32,32,32,32,32"
lappend arg_list "--component-param=AVL_MAX_SIZE=4"
lappend arg_list "--component-param=BYTE_ENABLE=true"
lappend arg_list "--component-param=C2P_WRITE_CLOCK_ADD_PHASE=0.0"
lappend arg_list "--component-param=CALIBRATION_MODE=Skip"
lappend arg_list "--component-param=CALIB_REG_WIDTH=8"
lappend arg_list "--component-param=CFG_DATA_REORDERING_TYPE=INTER_BANK"
lappend arg_list "--component-param=CFG_REORDER_DATA=true"
lappend arg_list "--component-param=CFG_TCCD_NS=2.5"
lappend arg_list "--component-param=COMMAND_PHASE=0.0"
lappend arg_list "--component-param=CONTROLLER_LATENCY=5"
lappend arg_list "--component-param=CORE_DEBUG_CONNECTION=EXPORT"
lappend arg_list "--component-param=CPORT_TYPE_PORT=Bidirectional,Bidirectional,Bidirectional,Bidirectional,Bidirectional,Bidirectional"
lappend arg_list "--component-param=CTL_AUTOPCH_EN=false"
lappend arg_list "--component-param=CTL_CMD_QUEUE_DEPTH=8"
lappend arg_list "--component-param=CTL_CSR_CONNECTION=INTERNAL_JTAG"
lappend arg_list "--component-param=CTL_CSR_ENABLED=false"
lappend arg_list "--component-param=CTL_CSR_READ_ONLY=1"
lappend arg_list "--component-param=CTL_DEEP_POWERDN_EN=false"
lappend arg_list "--component-param=CTL_DYNAMIC_BANK_ALLOCATION=false"
lappend arg_list "--component-param=CTL_DYNAMIC_BANK_NUM=4"
lappend arg_list "--component-param=CTL_ECC_AUTO_CORRECTION_ENABLED=false"
lappend arg_list "--component-param=CTL_ECC_ENABLED=false"
lappend arg_list "--component-param=CTL_ENABLE_BURST_INTERRUPT=false"
lappend arg_list "--component-param=CTL_ENABLE_BURST_TERMINATE=false"
lappend arg_list "--component-param=CTL_HRB_ENABLED=false"
lappend arg_list "--component-param=CTL_LOOK_AHEAD_DEPTH=4"
lappend arg_list "--component-param=CTL_SELF_REFRESH_EN=false"
lappend arg_list "--component-param=CTL_USR_REFRESH_EN=false"
lappend arg_list "--component-param=CTL_ZQCAL_EN=false"
lappend arg_list "--component-param=CUT_NEW_FAMILY_TIMING=true"
lappend arg_list "--component-param=DAT_DATA_WIDTH=32"
lappend arg_list "--component-param=DEBUG_MODE=false"
lappend arg_list "--component-param=DEVICE_DEPTH=1"
lappend arg_list "--component-param=DEVICE_FAMILY_PARAM="
lappend arg_list "--component-param=DISABLE_CHILD_MESSAGING=false"
lappend arg_list "--component-param=DISCRETE_FLY_BY=true"
lappend arg_list "--component-param=DLL_SHARING_MODE=None"
lappend arg_list "--component-param=DQS_DQSN_MODE=DIFFERENTIAL"
lappend arg_list "--component-param=DQ_INPUT_REG_USE_CLKN=false"
lappend arg_list "--component-param=DUPLICATE_AC=false"
lappend arg_list "--component-param=ED_EXPORT_SEQ_DEBUG=false"
lappend arg_list "--component-param=ENABLE_ABS_RAM_MEM_INIT=false"
lappend arg_list "--component-param=ENABLE_BONDING=false"
lappend arg_list "--component-param=ENABLE_BURST_MERGE=false"
lappend arg_list "--component-param=ENABLE_CTRL_AVALON_INTERFACE=true"
lappend arg_list "--component-param=ENABLE_DELAY_CHAIN_WRITE=false"
lappend arg_list "--component-param=ENABLE_EMIT_BFM_MASTER=false"
lappend arg_list "--component-param=ENABLE_EXPORT_SEQ_DEBUG_BRIDGE=false"
lappend arg_list "--component-param=ENABLE_EXTRA_REPORTING=false"
lappend arg_list "--component-param=ENABLE_ISS_PROBES=false"
lappend arg_list "--component-param=ENABLE_NON_DESTRUCTIVE_CALIB=false"
lappend arg_list "--component-param=ENABLE_NON_DES_CAL=false"
lappend arg_list "--component-param=ENABLE_NON_DES_CAL_TEST=false"
lappend arg_list "--component-param=ENABLE_SEQUENCER_MARGINING_ON_BY_DEFAULT=false"
lappend arg_list "--component-param=ENABLE_USER_ECC=false"
lappend arg_list "--component-param=EXPORT_AFI_HALF_CLK=false"
lappend arg_list "--component-param=EXTRA_SETTINGS="
lappend arg_list "--component-param=FIX_READ_LATENCY=8"
lappend arg_list "--component-param=FORCED_NON_LDC_ADDR_CMD_MEM_CK_INVERT=false"
lappend arg_list "--component-param=FORCED_NUM_WRITE_FR_CYCLE_SHIFTS=0"
lappend arg_list "--component-param=FORCE_DQS_TRACKING=AUTO"
lappend arg_list "--component-param=FORCE_MAX_LATENCY_COUNT_WIDTH=0"
lappend arg_list "--component-param=FORCE_SEQUENCER_TCL_DEBUG_MODE=false"
lappend arg_list "--component-param=FORCE_SHADOW_REGS=AUTO"
lappend arg_list "--component-param=FORCE_SYNTHESIS_LANGUAGE="
lappend arg_list "--component-param=HARD_EMIF=false"
lappend arg_list "--component-param=HCX_COMPAT_MODE=false"
lappend arg_list "--component-param=HHP_HPS=false"
lappend arg_list "--component-param=HHP_HPS_SIMULATION=false"
lappend arg_list "--component-param=HHP_HPS_VERIFICATION=false"
lappend arg_list "--component-param=HPS_PROTOCOL=DEFAULT"
lappend arg_list "--component-param=INCLUDE_BOARD_DELAY_MODEL=false"
lappend arg_list "--component-param=INCLUDE_MULTIRANK_BOARD_DELAY_MODEL=false"
lappend arg_list "--component-param=IS_ES_DEVICE=false"
lappend arg_list "--component-param=LOCAL_ID_WIDTH=8"
lappend arg_list "--component-param=LRDIMM_EXTENDED_CONFIG=0x0"
lappend arg_list "--component-param=MARGIN_VARIATION_TEST=false"
lappend arg_list "--component-param=MAX_PENDING_RD_CMD=32"
lappend arg_list "--component-param=MAX_PENDING_WR_CMD=16"
lappend arg_list "--component-param=MEM_ASR=Manual"
lappend arg_list "--component-param=MEM_ATCL=Disabled"
lappend arg_list "--component-param=MEM_AUTO_LEVELING_MODE=true"
lappend arg_list "--component-param=MEM_BANKADDR_WIDTH=3"
lappend arg_list "--component-param=MEM_BL=OTF"
lappend arg_list "--component-param=MEM_BT=Sequential"
lappend arg_list "--component-param=MEM_CK_PHASE=0.0"
lappend arg_list "--component-param=MEM_CK_WIDTH=1"
lappend arg_list "--component-param=MEM_CLK_EN_WIDTH=1"
lappend arg_list "--component-param=MEM_CLK_FREQ=324.0"
lappend arg_list "--component-param=MEM_CLK_FREQ_MAX=800.0"
lappend arg_list "--component-param=MEM_COL_ADDR_WIDTH=10"
lappend arg_list "--component-param=MEM_CS_WIDTH=1"
lappend arg_list "--component-param=MEM_DEVICE=MISSING_MODEL"
lappend arg_list "--component-param=MEM_DLL_EN=true"
lappend arg_list "--component-param=MEM_DQ_PER_DQS=8"
lappend arg_list "--component-param=MEM_DQ_WIDTH=16"
lappend arg_list "--component-param=MEM_DRV_STR=RZQ/6"
lappend arg_list "--component-param=MEM_FORMAT=DISCRETE"
lappend arg_list "--component-param=MEM_GUARANTEED_WRITE_INIT=false"
lappend arg_list "--component-param=MEM_IF_BOARD_BASE_DELAY=10"
lappend arg_list "--component-param=MEM_IF_DM_PINS_EN=true"
lappend arg_list "--component-param=MEM_IF_DQSN_EN=true"
lappend arg_list "--component-param=MEM_IF_SIM_VALID_WINDOW=0"
lappend arg_list "--component-param=MEM_INIT_EN=false"
lappend arg_list "--component-param=MEM_INIT_FILE="
lappend arg_list "--component-param=MEM_MIRROR_ADDRESSING=0"
lappend arg_list "--component-param=MEM_NUMBER_OF_DIMMS=1"
lappend arg_list "--component-param=MEM_NUMBER_OF_RANKS_PER_DEVICE=1"
lappend arg_list "--component-param=MEM_NUMBER_OF_RANKS_PER_DIMM=1"
lappend arg_list "--component-param=MEM_PD=DLL off"
lappend arg_list "--component-param=MEM_RANK_MULTIPLICATION_FACTOR=1"
lappend arg_list "--component-param=MEM_ROW_ADDR_WIDTH=14"
lappend arg_list "--component-param=MEM_RTT_NOM=RZQ/2"
lappend arg_list "--component-param=MEM_RTT_WR=RZQ/2"
lappend arg_list "--component-param=MEM_SRT=Normal"
lappend arg_list "--component-param=MEM_TCL=7"
lappend arg_list "--component-param=MEM_TFAW_NS=35.0"
lappend arg_list "--component-param=MEM_TINIT_US=500"
lappend arg_list "--component-param=MEM_TMRD_CK=4"
lappend arg_list "--component-param=MEM_TRAS_NS=35.0"
lappend arg_list "--component-param=MEM_TRCD_NS=13.75"
lappend arg_list "--component-param=MEM_TREFI_US=7.8"
lappend arg_list "--component-param=MEM_TRFC_NS=160.0"
lappend arg_list "--component-param=MEM_TRP_NS=13.75"
lappend arg_list "--component-param=MEM_TRRD_NS=7.5"
lappend arg_list "--component-param=MEM_TRTP_NS=7.5"
lappend arg_list "--component-param=MEM_TWR_NS=15.0"
lappend arg_list "--component-param=MEM_TWTR=6"
lappend arg_list "--component-param=MEM_USER_LEVELING_MODE=Leveling"
lappend arg_list "--component-param=MEM_VENDOR=Micron"
lappend arg_list "--component-param=MEM_VERBOSE=true"
lappend arg_list "--component-param=MEM_VOLTAGE=1.5V DDR3"
lappend arg_list "--component-param=MEM_WTCL=6"
lappend arg_list "--component-param=MRS_MIRROR_PING_PONG_ATSO=false"
lappend arg_list "--component-param=MULTICAST_EN=false"
lappend arg_list "--component-param=NEXTGEN=true"
lappend arg_list "--component-param=NIOS_ROM_DATA_WIDTH=32"
lappend arg_list "--component-param=NUM_DLL_SHARING_INTERFACES=1"
lappend arg_list "--component-param=NUM_EXTRA_REPORT_PATH=10"
lappend arg_list "--component-param=NUM_OCT_SHARING_INTERFACES=1"
lappend arg_list "--component-param=NUM_OF_PORTS=1"
lappend arg_list "--component-param=NUM_PLL_SHARING_INTERFACES=1"
lappend arg_list "--component-param=OCT_SHARING_MODE=None"
lappend arg_list "--component-param=P2C_READ_CLOCK_ADD_PHASE=0.0"
lappend arg_list "--component-param=PACKAGE_DESKEW=false"
lappend arg_list "--component-param=PARSE_FRIENDLY_DEVICE_FAMILY_PARAM="
lappend arg_list "--component-param=PARSE_FRIENDLY_DEVICE_FAMILY_PARAM_VALID=false"
lappend arg_list "--component-param=PHY_CSR_CONNECTION=INTERNAL_JTAG"
lappend arg_list "--component-param=PHY_CSR_ENABLED=false"
lappend arg_list "--component-param=PHY_ONLY=false"
lappend arg_list "--component-param=PINGPONGPHY_EN=false"
lappend arg_list "--component-param=PLL_ADDR_CMD_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_ADDR_CMD_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_ADDR_CMD_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_ADDR_CMD_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_ADDR_CMD_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_ADDR_CMD_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_AFI_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_AFI_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_AFI_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_AFI_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_AFI_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_AFI_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_AFI_HALF_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_AFI_HALF_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_AFI_HALF_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_AFI_HALF_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_AFI_HALF_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_AFI_HALF_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_AFI_PHY_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_AFI_PHY_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_AFI_PHY_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_AFI_PHY_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_AFI_PHY_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_AFI_PHY_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_C2P_WRITE_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_C2P_WRITE_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_C2P_WRITE_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_C2P_WRITE_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_C2P_WRITE_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_C2P_WRITE_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_CLK_PARAM_VALID=false"
lappend arg_list "--component-param=PLL_CONFIG_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_CONFIG_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_CONFIG_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_CONFIG_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_CONFIG_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_CONFIG_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_DR_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_DR_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_DR_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_DR_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_DR_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_DR_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_HR_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_HR_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_HR_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_HR_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_HR_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_HR_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_LOCATION=Top_Bottom"
lappend arg_list "--component-param=PLL_MEM_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_MEM_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_MEM_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_MEM_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_MEM_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_MEM_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_NIOS_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_NIOS_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_NIOS_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_NIOS_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_NIOS_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_NIOS_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_P2C_READ_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_P2C_READ_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_P2C_READ_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_P2C_READ_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_P2C_READ_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_P2C_READ_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_SHARING_MODE=None"
lappend arg_list "--component-param=PLL_WRITE_CLK_DIV_PARAM=0"
lappend arg_list "--component-param=PLL_WRITE_CLK_FREQ_PARAM=0.0"
lappend arg_list "--component-param=PLL_WRITE_CLK_FREQ_SIM_STR_PARAM="
lappend arg_list "--component-param=PLL_WRITE_CLK_MULT_PARAM=0"
lappend arg_list "--component-param=PLL_WRITE_CLK_PHASE_PS_PARAM=0"
lappend arg_list "--component-param=PLL_WRITE_CLK_PHASE_PS_SIM_STR_PARAM="
lappend arg_list "--component-param=POWER_OF_TWO_BUS=false"
lappend arg_list "--component-param=PRIORITY_PORT=1,1,1,1,1,1"
lappend arg_list "--component-param=RATE=Half"
lappend arg_list "--component-param=RDIMM_CONFIG=0"
lappend arg_list "--component-param=READ_DQ_DQS_CLOCK_SOURCE=INVERTED_DQS_BUS"
lappend arg_list "--component-param=READ_FIFO_SIZE=8"
lappend arg_list "--component-param=REFRESH_BURST_VALIDATION=false"
lappend arg_list "--component-param=REFRESH_INTERVAL=15000"
lappend arg_list "--component-param=REF_CLK_FREQ=27.0"
lappend arg_list "--component-param=REF_CLK_FREQ_MAX_PARAM=0.0"
lappend arg_list "--component-param=REF_CLK_FREQ_MIN_PARAM=0.0"
lappend arg_list "--component-param=REF_CLK_FREQ_PARAM_VALID=false"
lappend arg_list "--component-param=SEQUENCER_TYPE=NIOS"
lappend arg_list "--component-param=SEQ_MODE=0"
lappend arg_list "--component-param=SKIP_MEM_INIT=true"
lappend arg_list "--component-param=SOPC_COMPAT_RESET=false"
lappend arg_list "--component-param=SPEED_GRADE=7"
lappend arg_list "--component-param=STARVE_LIMIT=10"
lappend arg_list "--component-param=SYS_INFO_DEVICE_FAMILY=Cyclone V"
lappend arg_list "--component-param=TIMING_BOARD_AC_EYE_REDUCTION_H=0.0"
lappend arg_list "--component-param=TIMING_BOARD_AC_EYE_REDUCTION_SU=0.0"
lappend arg_list "--component-param=TIMING_BOARD_AC_SKEW=0.02"
lappend arg_list "--component-param=TIMING_BOARD_AC_SLEW_RATE=1.0"
lappend arg_list "--component-param=TIMING_BOARD_AC_TO_CK_SKEW=0.0"
lappend arg_list "--component-param=TIMING_BOARD_CK_CKN_SLEW_RATE=2.0"
lappend arg_list "--component-param=TIMING_BOARD_DELTA_DQS_ARRIVAL_TIME=0.0"
lappend arg_list "--component-param=TIMING_BOARD_DELTA_READ_DQS_ARRIVAL_TIME=0.0"
lappend arg_list "--component-param=TIMING_BOARD_DERATE_METHOD=AUTO"
lappend arg_list "--component-param=TIMING_BOARD_DQS_DQSN_SLEW_RATE=2.0"
lappend arg_list "--component-param=TIMING_BOARD_DQ_EYE_REDUCTION=0.0"
lappend arg_list "--component-param=TIMING_BOARD_DQ_SLEW_RATE=1.0"
lappend arg_list "--component-param=TIMING_BOARD_DQ_TO_DQS_SKEW=0.0"
lappend arg_list "--component-param=TIMING_BOARD_ISI_METHOD=AUTO"
lappend arg_list "--component-param=TIMING_BOARD_MAX_CK_DELAY=0.6"
lappend arg_list "--component-param=TIMING_BOARD_MAX_DQS_DELAY=0.6"
lappend arg_list "--component-param=TIMING_BOARD_READ_DQ_EYE_REDUCTION=0.0"
lappend arg_list "--component-param=TIMING_BOARD_SKEW_BETWEEN_DIMMS=0.05"
lappend arg_list "--component-param=TIMING_BOARD_SKEW_BETWEEN_DQS=0.02"
lappend arg_list "--component-param=TIMING_BOARD_SKEW_CKDQS_DIMM_MAX=0.01"
lappend arg_list "--component-param=TIMING_BOARD_SKEW_CKDQS_DIMM_MIN=-0.01"
lappend arg_list "--component-param=TIMING_BOARD_SKEW_WITHIN_DQS=0.02"
lappend arg_list "--component-param=TIMING_BOARD_TDH=0.0"
lappend arg_list "--component-param=TIMING_BOARD_TDS=0.0"
lappend arg_list "--component-param=TIMING_BOARD_TIH=0.0"
lappend arg_list "--component-param=TIMING_BOARD_TIS=0.0"
lappend arg_list "--component-param=TIMING_TDH=45"
lappend arg_list "--component-param=TIMING_TDQSCK=225"
lappend arg_list "--component-param=TIMING_TDQSCKDL=1200"
lappend arg_list "--component-param=TIMING_TDQSCKDM=900"
lappend arg_list "--component-param=TIMING_TDQSCKDS=450"
lappend arg_list "--component-param=TIMING_TDQSQ=100"
lappend arg_list "--component-param=TIMING_TDQSS=0.27"
lappend arg_list "--component-param=TIMING_TDS=10"
lappend arg_list "--component-param=TIMING_TDSH=0.18"
lappend arg_list "--component-param=TIMING_TDSS=0.18"
lappend arg_list "--component-param=TIMING_TIH=120"
lappend arg_list "--component-param=TIMING_TIS=170"
lappend arg_list "--component-param=TIMING_TQH=0.38"
lappend arg_list "--component-param=TIMING_TQSH=0.4"
lappend arg_list "--component-param=TRACKING_ERROR_TEST=false"
lappend arg_list "--component-param=TRACKING_WATCH_TEST=false"
lappend arg_list "--component-param=TREFI=35100"
lappend arg_list "--component-param=TRFC=350"
lappend arg_list "--component-param=USER_DEBUG_LEVEL=1"
lappend arg_list "--component-param=USE_AXI_ADAPTOR=false"
lappend arg_list "--component-param=USE_FAKE_PHY=false"
lappend arg_list "--component-param=USE_MEM_CLK_FREQ=false"
lappend arg_list "--component-param=USE_MM_ADAPTOR=true"
lappend arg_list "--component-param=USE_SEQUENCER_BFM=false"
lappend arg_list "--component-param=WEIGHT_PORT=0,0,0,0,0,0"
lappend arg_list "--component-param=WRBUFFER_ADDR_WIDTH=6"
set qdir $::env(QUARTUS_ROOTDIR)
catch {eval [concat [list exec "$qdir/sopc_builder/bin/ip-generate" --component-name=alt_mem_if_ddr3_tg_eds] $arg_list]} temp
puts $temp

set spd_filename [file join $hdl_language ${variant_name}.spd]
catch {eval [list exec "$qdir/sopc_builder/bin/ip-make-simscript" --spd=${spd_filename} --compile-to-work --output-directory=${hdl_language}]} temp
puts $temp

set scripts [list [file join $hdl_language synopsys vcs vcs_setup.sh] [file join $hdl_language synopsys vcsmx vcsmx_setup.sh] [file join $hdl_language cadence ncsim_setup.sh]]
foreach scriptname $scripts {
	if {[catch {set fh [open $scriptname r]} temp]} {
	} else {
		set lines [split [read $fh] "\n"]
		close $fh
		if {[catch {set fh [open $scriptname w]} temp]} {
			post_message -type warning "$temp"
		} else {
			foreach line $lines {
				if {[regexp -- {USER_DEFINED_SIM_OPTIONS\s*=.*\+vcs\+finish\+100} $line]} {
					regsub -- {\+vcs\+finish\+100} $line {} line
				} elseif {[regexp -- {USER_DEFINED_SIM_OPTIONS\s*=.*-input \\\"@run 100; exit\\\"} $line]} {
					regsub -- {-input \\\"@run 100; exit\\\"} $line {} line
				}
				puts $fh $line
			}
			close $fh
		}
	}
}
