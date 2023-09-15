// Copyright 2006, Traversal Technology
// Copyright 2006, Petter Urkedal
// This code is licensed under GPL.
// For alternative licensing, see Traversal's dual-licensing contract.

// Define to build without timing configuration.
//`define FIXED_TIMING 1
//
// TODO
//   * Generate 'mem_clock' and 'mem_clock_' signals.
//   * Implement correct data sampling and generate strobe signal for write.
//   * Replace 'testrom' with appropriate memory.

module mem_ctl(clock, reset_,
               req_tag, req_cmd, req_addr, req_data, req_mask,
               busy, rd_avail, rd_tag,
               mem_clock, mem_clock_, mem_cke, mem_bank, mem_addr,
               mem_cmd, mem_dm, mem_dq, mem_dqs
`ifdef INIT_PROGRAMMABLE
               , init_write_clock, init_write_enable,
               init_write_addr, init_write_data
`endif
            );
    parameter CHIP_COUNT = 2;
        // Number of chips to control. The chips are driven in parallel
        // and adds to the data width.
    parameter T_DATA = 1;
        // The burst time in cycles for read or write. This is the ceil of
        // half of the number of data transfers per burst.

    // Bus Widths
    parameter TAG_WIDTH = 4;
    parameter CMD_WIDTH = 2;
    parameter COL_WIDTH = 9;
    parameter ROW_WIDTH = 12;
    parameter BANK_WIDTH = 2;
    parameter ADDR_WIDTH = COL_WIDTH + ROW_WIDTH + BANK_WIDTH;
    parameter   ADDR_COL_OFFSET = 0;
    parameter   ADDR_ROW_OFFSET = COL_WIDTH;
    parameter   ADDR_BANK_OFFSET = ADDR_ROW_OFFSET + ROW_WIDTH;
    parameter DATA_WIDTH = 16*CHIP_COUNT;
    parameter MASK_WIDTH = DATA_WIDTH/8;
    parameter BANK_COUNT = 1 << BANK_WIDTH;

    // Commands
    parameter CMD_NOOP = 2'b00;
    parameter CMD_READ = 2'b01;
    parameter CMD_WRITE = 2'b10;
    parameter CMD_REFRESH = 2'b11;

    // Client Connectors
    input clock;
    input reset_;
    input[TAG_WIDTH-1:0] req_tag;
    input[CMD_WIDTH-1:0] req_cmd;
    input[ADDR_WIDTH-1:0] req_addr;
    input[DATA_WIDTH-1:0] req_data;
    input[MASK_WIDTH-1:0] req_mask;
    output busy;
    output rd_avail;
    output[TAG_WIDTH-1:0] rd_tag;

    // DDR Connectors
    // Some of the ports connects to both memories, for others the lines are
    // split between them.
    parameter MEM_ADDR_WIDTH = 12;
    parameter MEM_CMD_NOOP      = 3'b111;
    parameter MEM_CMD_READ      = 3'b101;
    parameter MEM_CMD_WRITE     = 3'b100;
    parameter MEM_CMD_PRECHARGE = 3'b010;
    parameter MEM_CMD_ACTIVATE  = 3'b011;
    parameter MEM_CMD_REFRESH   = 3'b001;
    parameter MEM_CMD_LOAD_MODE = 3'b000;
    output mem_clock, mem_clock_, mem_cke;
    output[BANK_WIDTH-1:0] mem_bank;
    output[MEM_ADDR_WIDTH-1:0] mem_addr;
    output[2:0] mem_cmd; // = {mem_ras_,mem_cas_,mem_we_}
    output[DATA_WIDTH/8-1:0] mem_dm;
    inout[DATA_WIDTH-1:0] mem_dq;
    inout[CHIP_COUNT-1:0] mem_dqs;

    // Interface to program the initialisation BRAM
`ifdef INIT_PROGRAMMABLE
    input init_write_clock;
    input init_write_enable;
    input[8:0] init_write_addr;
    input[7:0] init_write_data;
`endif

`define ADDR_BANK_SLICE [ADDR_BANK_OFFSET+BANK_WIDTH-1:ADDR_BANK_OFFSET]
`define ADDR_COL_SLICE  [ADDR_COL_OFFSET +COL_WIDTH -1:ADDR_COL_OFFSET ]
`define ADDR_ROW_SLICE  [ADDR_ROW_OFFSET +ROW_WIDTH -1:ADDR_ROW_OFFSET ]


// Timing configuration
//
parameter uet_read_to_precharge = {T_DATA{1'b1}};

`ifndef FIXED_TIMING
parameter T_CL_MAX = 3;
parameter T_PAR_MAX = 80;  // precharge, activate, refresh
parameter T_READ_MAX = 25;
parameter T_WRITE_MAX = 25;
parameter T_RW_MAX = T_READ_MAX > T_WRITE_MAX? T_READ_MAX : T_WRITE_MAX;

parameter UET_DATA = {T_DATA{1'b1}};

// Each of the following is unary encoded and 1 less than the actual number
// of cycles.
reg[T_CL_MAX-2:0]     uet_cl;
reg[T_PAR_MAX-2:0]    uet_precharge_to_any; // tRP, time before active/refresh
reg[T_PAR_MAX-2:0]    uet_activate_to_precharge;
reg[T_PAR_MAX-T_DATA-2:0] uet_write_to_precharge_p;
wire[T_PAR_MAX-2:0] uet_write_to_precharge={uet_write_to_precharge_p,UET_DATA};
reg[T_RW_MAX-2:0]     uet_activate_to_rw;
wire[T_CL_MAX+T_DATA-2:0] uet_read_to_write = {uet_cl, UET_DATA};
reg[T_READ_MAX-T_DATA-2:0] uet_write_to_read_p;
wire[T_READ_MAX-2:0]  uet_write_to_read = {uet_write_to_read_p, UET_DATA};
reg[T_PAR_MAX-2:0]    uet_refresh_to_activate;

`else
parameter uet_precharge_to_any = {14{1'b1}};
parameter uet_activate_to_precharge = {39{1'b1}};
parameter uet_write_to_precharge = {14{1'b1}};
parameter uet_activate_to_rw = {14{1'b1}};
parameter uet_read_to_write = {2{1'b1}};
parameter uet_write_to_read = {7{1'b1}};
parameter uet_refresh_to_activate = {69{1'b1}};

parameter T_CL = 3;
parameter T_CL_MAX = 3;
parameter T_PAR_MAX = 70;
parameter T_READ_MAX = 15;
parameter T_WRITE_MAX = 15;
`endif


// Interface to DDR and dealing with DDR, CAS latency and tDQSS.
//
parameter MEM_IOQ_CMD_NOOP = 2'b00;
parameter MEM_IOQ_CMD_READ = 2'b01;
parameter MEM_IOQ_CMD_WRITE = 2'b10;
reg[1:0]            ioq_cmd;
reg[MASK_WIDTH-1:0] ioq_mask;
reg[DATA_WIDTH-1:0] ioq_data_or_tag;

integer i;
parameter T_DQSS = 1;
parameter MEM_IOQ_LENGTH = T_CL_MAX;
parameter MEM_IOQ_CMDBIT_READ = DATA_WIDTH+MASK_WIDTH;
parameter MEM_IOQ_CMDBIT_WRITE = DATA_WIDTH+MASK_WIDTH+1;
reg[DATA_WIDTH+MASK_WIDTH+1:0] ioq_arr[0:MEM_IOQ_LENGTH-1];
wire[DATA_WIDTH+MASK_WIDTH+1:0] ioq_current = ioq_arr[0];
always @(posedge clock) begin
    for (i = 1; i < MEM_IOQ_LENGTH; i = i + 1)
        ioq_arr[i - 1] <= ioq_arr[i];
    ioq_arr[MEM_IOQ_LENGTH-1] <= {MEM_IOQ_CMD_NOOP, ioq_mask, ioq_data_or_tag};
    if (ioq_cmd[0]) begin // read
`ifndef FIXED_TIMING
        if (!uet_cl[0])      // CL = 1
            ioq_arr[0] <= {ioq_cmd, {MASK_WIDTH{1'b1}}, ioq_data_or_tag};
        else if (!uet_cl[1]) // CL = 2
            ioq_arr[1] <= {ioq_cmd, {MASK_WIDTH{1'b1}}, ioq_data_or_tag};
        else                 // CL = 3
            ioq_arr[2] <= {ioq_cmd, {MASK_WIDTH{1'b1}}, ioq_data_or_tag};
`else
        ioq_arr[T_CL-1] <= {ioq_cmd, {MASK_WIDTH{1'b1}}, ioq_data_or_tag};
`endif
    end
    if (ioq_cmd[1]) // write
        ioq_arr[T_DQSS-1] <= {ioq_cmd, ioq_mask, ioq_data_or_tag};
end
reg mem_cke;
reg[2:0] mem_cmd;
reg[BANK_WIDTH-1:0] mem_bank;
reg[MEM_ADDR_WIDTH-1:0] mem_addr;
assign mem_dq = ioq_current[MEM_IOQ_CMDBIT_WRITE]
                  ? ioq_current[DATA_WIDTH-1:0] : 32'bz;
assign mem_dm = ioq_current[DATA_WIDTH+MASK_WIDTH-1:DATA_WIDTH];
assign rd_avail = ioq_current[MEM_IOQ_CMDBIT_READ];
assign rd_tag = ioq_current[TAG_WIDTH-1:0];


wire busy;


// Stage 1. Look up pre-request open row and store post-request row.
//
reg[TAG_WIDTH-1:0] s1_req_tag;
reg[CMD_WIDTH-1:0] s1_req_cmd;
reg[ADDR_WIDTH-1:0] s1_req_addr;
reg[DATA_WIDTH-1:0] s1_req_data;
reg[MASK_WIDTH-1:0] s1_req_mask;
reg[ROW_WIDTH-1:0] s1_open_row;
reg[ROW_WIDTH-1:0] s1_open_row_arr[0:BANK_COUNT-1];
always @(posedge clock or negedge reset_) begin
    if (!reset_) begin
        s1_req_tag <= 0;
        s1_req_cmd <= CMD_NOOP;
        s1_req_addr <= 0;
        s1_req_data <= 0;
        s1_req_mask <= 0;
        s1_open_row <= 0;
        for (i = 0; i < BANK_COUNT; i = i + 1)
            s1_open_row_arr[i] <= 0;
    end else if (!busy) begin
        s1_req_tag  <= req_tag;
        s1_req_cmd  <= req_cmd;
        s1_req_addr <= req_addr;
        s1_req_data <= req_data;
        s1_req_mask <= req_mask;

        case (req_cmd)
            CMD_READ, CMD_WRITE: begin
                s1_open_row <= s1_open_row_arr[req_addr`ADDR_BANK_SLICE];
                s1_open_row_arr[req_addr`ADDR_BANK_SLICE]
                    <= req_addr`ADDR_ROW_SLICE;
            end
        endcase
    end
end

// Stage 2. Check if row of current bank open and if we have a row hit.
//
reg[TAG_WIDTH-1:0] s2_req_tag;
reg[CMD_WIDTH-1:0] s2_req_cmd;
reg[ADDR_WIDTH-1:0] s2_req_addr;
reg[DATA_WIDTH-1:0] s2_req_data;
reg[MASK_WIDTH-1:0] s2_req_mask;
reg s2_row_is_open_arr[0:BANK_COUNT-1];
reg s2_row_is_open;
reg s2_maybe_row_hit;
always @(posedge clock or negedge reset_) begin
    if (!reset_) begin
        s2_req_tag <= 0;
        s2_req_cmd <= CMD_NOOP;
        s2_req_addr <= 0;
        s2_req_data <= 0;
        s2_req_mask <= 0;
        for (i = 0; i < BANK_COUNT; i = i + 1)
            s2_row_is_open_arr[i] <= 0;
        s2_row_is_open <= 0;
        s2_maybe_row_hit <= 0;
    end else if (!busy) begin
        s2_req_tag  <= s1_req_tag;
        s2_req_cmd  <= s1_req_cmd;
        s2_req_addr <= s1_req_addr;
        s2_req_data <= s1_req_data;
        s2_req_mask <= s1_req_mask;

        s2_maybe_row_hit <= s1_req_addr`ADDR_ROW_SLICE == s1_open_row;
        s2_row_is_open <= s2_row_is_open_arr[s1_req_addr`ADDR_BANK_SLICE];
        case (s1_req_cmd)
            CMD_REFRESH:
                for (i = 0; i < BANK_COUNT; i = i + 1)
                    s2_row_is_open_arr[i] <= 0;
            CMD_READ, CMD_WRITE:
                s2_row_is_open_arr[s1_req_addr`ADDR_BANK_SLICE] <= 1;
        endcase
    end
end


// Stage 4 Forward Declarations
//
// Unary encoded times until various actions can be performed.
reg[T_PAR_MAX-2:0] s4_uet_par;  // precharge, activate, or refresh
reg[T_READ_MAX-2:0] s4_uet_read;
reg[T_WRITE_MAX-2:0] s4_uet_write;


// Stage 3
//
reg[TAG_WIDTH-1:0] s3_req_tag;
reg[ADDR_WIDTH-1:0] s3_req_addr;
reg[DATA_WIDTH-1:0] s3_req_data;
reg[MASK_WIDTH-1:0] s3_req_mask;
reg s3_need_precharge;
reg s3_need_activate;
reg s3_need_refresh;
reg s3_is_read;
reg s3_is_write;
reg s3_par_busy;
always @(posedge clock or negedge reset_) begin
    if (!reset_) begin
        s3_req_tag <= 0;
        s3_req_addr <= 0;
        s3_req_data <= 0;
        s3_req_mask <= 0;
        s3_need_precharge <= 0;
        s3_need_activate <= 0;
        s3_need_refresh <= 0;
        s3_is_read <= 0;
        s3_is_write <= 0;
        s3_par_busy <= 0;
    end else begin
        // Stage 4 can not clear these flags, so we do it here. This is one
        // cycle too late, but the counter delays should take care of that.
        if (!s4_uet_par[0]) begin
            if (!s3_need_precharge) begin
                s3_need_activate <= 0;
                s3_need_refresh <= 0;
                s3_par_busy <= 0;
            end
            s3_need_precharge <= 0;
        end

        if (!busy) begin
            s3_req_tag <= s2_req_tag;
            s3_req_addr <= s2_req_addr;
            s3_req_data <= s2_req_data;
            s3_req_mask <= s2_req_mask;

            s3_par_busy <= 1;
            s3_is_read <= s2_req_cmd == CMD_READ;
            s3_is_write <= s2_req_cmd == CMD_WRITE;
            case (s2_req_cmd)
                CMD_NOOP:
                    s3_par_busy <= 0;
                CMD_READ, CMD_WRITE: begin
                    if (s2_row_is_open) begin
                        if (!s2_maybe_row_hit) begin
                            $display("STG3 %x@%x, row miss, cmd=%x",
                                     s2_req_tag, s2_req_addr, s2_req_cmd);
                            s3_need_precharge <= 1;
                            s3_need_activate <= 1;
                        end else begin
                            $display("STG3 %x@%x, row hit, cmd=%x",
                                     s2_req_tag, s2_req_addr, s2_req_cmd);
                            s3_par_busy <= 0;
                        end
                    end else begin
                        $display("STG3 %x@%x, no open row, cmd=%x",
                                 s2_req_tag, s2_req_addr, s2_req_cmd);
                        s3_need_activate <= 1;
                    end
                end
                CMD_REFRESH: begin
                    s3_need_precharge <= 1;
                    s3_need_refresh <= 1;
                end
            endcase
        end
    end
end

// Initialisation
//
// Instruction format:
//     if bit 7 is set,
//         left-shift remaining 7 bits into address, issue NOOP to memory
//     else
//         insn[2:0]: DDR Command {RAS_, CAS_, WE_}.
//         insn[3]: CKE
//         insn[4]: Memory bank bit 0, used to select extended mode reg.
//         insn[5]: Hold current signals for 32 cycles.
//         insn[6]: 1 indicates that initialisation sequence is finished.
reg[9:0] init_pc;
wire[7:0] init_insn;
`ifdef INIT_PROGRAMMABLE
RAMB16_S36_S36 mprg_ram (
   .DOA(init_insn), .DOPA(),
   .DOB(), .DOPB(),
   .ADDRA(init_pc),  .CLKA(clock),
   .DIA(32'b0),  .DIPA(4'b0),
   .DIB(init_write_data),  .DIPB(4'b0),
   .ADDRB(init_write_addr[8:0]),  .CLKB(init_write_clock),
   .ENA(1'b1), .SSRA(1'b0),
   .ENB(1'b1), .SSRB(1'b0),
   .WEA(1'b0), .WEB(init_write_enable));
`else
testrom #(.ROM_IMAGE("mem_ctl_init.memh"), .DATA_WIDTH(8))
        insn_mem(clock, init_pc, init_insn);
`endif

// Stage 4
//
reg s4_initialising;

assign busy = s3_is_read && s4_uet_read[0]
           || s3_is_write && s4_uet_write[0]
           || s4_initialising || s3_par_busy;

always @(posedge clock or negedge reset_) begin
    if (!reset_) begin
        s4_uet_par <= 0;
        s4_uet_read <= 0;
        s4_uet_write <= 0;
        mem_cke <= 0;
        mem_cmd <= MEM_CMD_NOOP;
        mem_bank <= 0;
        mem_addr <= 0;
        ioq_cmd <= MEM_IOQ_CMD_NOOP;
        ioq_data_or_tag <= 0;
        ioq_mask <= 0;
        s4_initialising <= 1;
        init_pc <= 0;

`ifndef FIXED_TIMING
        uet_cl <= 0;
        uet_precharge_to_any <= 0;
        uet_activate_to_precharge <= 0;
        uet_write_to_precharge_p <= 0;
        uet_activate_to_rw <= 0;
        uet_write_to_read_p <= 0;
        uet_refresh_to_activate <= 0;
`endif
    end else begin
        s4_uet_par   <= s4_uet_par   >> 1;
        s4_uet_read  <= s4_uet_read  >> 1;
        s4_uet_write <= s4_uet_write >> 1;
        ioq_cmd <= MEM_IOQ_CMD_NOOP;

        if (s4_initialising) begin
            if (!s4_uet_par[0]) begin
                $display("INIT insn-%x", init_insn);
                if (init_insn[7]) begin
                    mem_cmd <= MEM_CMD_NOOP;
                    mem_cke <= 1;
                    mem_addr <= (mem_addr << 7) | init_insn[6:0];
                end else if (init_insn[6]) begin
                    if (init_insn[5])
                        s4_initialising <= 0;
                    else begin
`ifndef FIXED_TIMING
                        case (init_insn[2:0])
                            3'h0: uet_cl <= (uet_cl << 1) | 1'b1;
                            3'h1: uet_precharge_to_any <=
                                    (uet_precharge_to_any << 1) | 1'b1;
                            3'h2: uet_activate_to_precharge <=
                                    (uet_activate_to_precharge << 1) | 1'b1;
                            3'h3: uet_write_to_precharge_p <=
                                    (uet_write_to_precharge_p << 1) | 1'b1;
                            3'h4: uet_activate_to_rw <=
                                    (uet_activate_to_rw << 1) | 1'b1;
                            3'h5: uet_write_to_read_p <=
                                    (uet_write_to_read_p << 1) | 1'b1;
                            3'h6: uet_refresh_to_activate <=
                                    (uet_refresh_to_activate << 1) | 1'b1;
                        endcase
`endif
                    end
                end else begin
                    mem_cmd <= init_insn[2:0];
                    mem_cke <= init_insn[3];
                    mem_bank <= {1'b0, init_insn[4]};
                    if (init_insn[5])
                        s4_uet_par <= {31{1'b1}};
                end
                init_pc <= init_pc + 1;
            end
        end else if (s3_par_busy) begin
            mem_cmd <= MEM_CMD_NOOP;
            if (!s4_uet_par[0]) begin
                if (s3_need_precharge) begin
                    $display("STG4 %x@%x, BANK %x, precharging",
                             s3_req_tag, s3_req_addr,
                             s3_req_addr`ADDR_BANK_SLICE);
                    mem_cmd <= MEM_CMD_PRECHARGE;
                    mem_bank <= s3_req_addr`ADDR_BANK_SLICE;
                    mem_addr[10] <= s3_need_refresh;

                    // s3_need_precharge <= 0; // see stage 3
                    s4_uet_par <= uet_precharge_to_any;
                end else begin
                    if (s3_need_activate) begin
                        $display("STG4 %x@%x, BANK %x, activating row %x",
                                 s3_req_tag, s3_req_addr,
                                 s3_req_addr`ADDR_BANK_SLICE,
                                 s3_req_addr`ADDR_ROW_SLICE);
                        mem_cmd <= MEM_CMD_ACTIVATE;
                        mem_bank <= s3_req_addr`ADDR_BANK_SLICE;
                        mem_addr <= s3_req_addr`ADDR_ROW_SLICE;

                        // s3_need_activate <= 0; // see stage 3
                        s4_uet_par <= uet_activate_to_precharge;
                        s4_uet_write <= uet_activate_to_rw;
                        s4_uet_read <= uet_activate_to_rw;
                    end
                    if (s3_need_refresh) begin
                        $display("STG4 REFRESH");
                        mem_cmd <= MEM_CMD_REFRESH;

                        s4_uet_par <= uet_refresh_to_activate;
                    end
                end
            end
        end else begin
            mem_cmd <= MEM_CMD_NOOP;
            if (s3_is_read) begin
                if (!s4_uet_read[0]) begin
                    $display("STG4 %x@%x, READ", s3_req_tag, s3_req_addr);
                    mem_cmd <= MEM_CMD_READ;
                    mem_bank <= s3_req_addr`ADDR_BANK_SLICE;
                    mem_addr <= s3_req_addr`ADDR_COL_SLICE;
                    ioq_cmd <= MEM_IOQ_CMD_READ;
                    ioq_data_or_tag <= s3_req_tag;

                    s4_uet_par <= (s4_uet_par >> 1) | uet_read_to_precharge;
                    s4_uet_write <= (s4_uet_write >> 1) | uet_read_to_write;
                end
            end
            if (s3_is_write) begin
                if (!s4_uet_write[0]) begin
                    $display("STG4 %x@%x, WRITE", s3_req_tag, s3_req_addr);
                    mem_cmd <= MEM_CMD_WRITE;
                    mem_bank <= s3_req_addr`ADDR_BANK_SLICE;
                    mem_addr <= s3_req_addr`ADDR_COL_SLICE;
                    ioq_cmd <= MEM_IOQ_CMD_WRITE;
                    ioq_mask <= s3_req_mask;
                    ioq_data_or_tag <= s3_req_data;

                    s4_uet_par <= (s4_uet_par >> 1) | uet_write_to_precharge;
                    s4_uet_read <= (s4_uet_read >> 1) | uet_write_to_read;
                end
            end
        end
    end
end

endmodule
// vim: expandtab
