`ifndef VIDEO_REGS_VH
`define VIDEO_REGS_VH

`define REG_MODE             8'h00
`define REG_ALGO_ENABLE      8'h01
`define REG_BRIGHTNESS_GAIN  8'h02
`define REG_GAMMA_SEL        8'h03
`define REG_SCALE_SEL        8'h04
`define REG_ROTATE_SEL       8'h05
`define REG_EDGE_SEL         8'h06
`define REG_OSD_SEL          8'h07
`define REG_STATUS           8'h08
`define REG_FPS_COUNTER      8'h09
`define REG_HEARTBEAT        8'h0A
`define REG_CAM_CMD          8'h10
`define REG_CAM_REG_ADDR     8'h11
`define REG_CAM_WR_DATA      8'h12
`define REG_CAM_RD_DATA      8'h13
`define REG_CAM_STATUS       8'h14
`define REG_CAM_FRAME_COUNT  8'h15
`define REG_CAM_LINE_COUNT   8'h16
`define REG_CAM_LAST_PIXEL   8'h17
`define REG_CAM_ERROR_COUNT  8'h18

`define MODE_BYPASS          16'h0000
`define MODE_GRAY            16'h0001
`define MODE_LOWLIGHT        16'h0002
`define MODE_INSPECT         16'h0003

`define CAM_CMD_READ         16'h0001
`define CAM_CMD_WRITE        16'h0002
`define CAM_CMD_CLEAR        16'h0004

`define CAM_STATUS_BUSY_BIT            0
`define CAM_STATUS_DONE_BIT            1
`define CAM_STATUS_ACK_OK_BIT          2
`define CAM_STATUS_NACK_BIT            3
`define CAM_STATUS_TIMEOUT_BIT         4
`define CAM_STATUS_INIT_DONE_BIT       5
`define CAM_STATUS_SENSOR_PRESENT_BIT  6
`define CAM_STATUS_DATA_ACTIVE_BIT     7

`define OV5640_CHIP_ID_HIGH_REG        16'h300A
`define OV5640_CHIP_ID_LOW_REG         16'h300B
`define OV5640_CHIP_ID_HIGH_VALUE      8'h56
`define OV5640_CHIP_ID_LOW_VALUE       8'h40

`endif
