module fir_controller (
    input  logic        clk,
    input  logic        rst_n,
    
    // AXI-Stream Slave (Input from SPI RX)
    input  logic [15:0] s_axis_tdata,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    
    // AXI-Stream Master (Output to SPI TX)
    output logic [15:0] m_axis_tdata,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready,
    
    // To/From Delay Line
    output logic        shift_en,
    output logic [3:0]  sel,
    output logic [15:0] data_in,
    input  logic [17:0] pre_adder_out,
    
    // To MAC Engine
    output logic        mac_valid,
    output logic        mac_clear,
    output logic signed [15:0] mac_x,
    output logic signed [15:0] mac_c,
    input  logic signed [15:0] mac_y,
    
    // Config Regs
    input  logic [15:0] coeff_mem [0:15]
);

    typedef enum logic [1:0] {IDLE, CALC, WAIT_AXI} state_t;
    state_t state;
    
    logic [4:0] calc_cnt; // 0 to 16
    logic [15:0] sample_reg;
    
    // drive delay line data_in safely whether in IDLE or CALC
    assign data_in = (state == IDLE) ? s_axis_tdata : sample_reg;
    
    assign s_axis_tready = (state == IDLE);
    
    // pass truncated 16-bit to MAC (MAC only takes 16 bit X)
    assign mac_x = pre_adder_out[15:0];
    
    always_comb begin
        if (calc_cnt < 16) begin
            mac_c = coeff_mem[calc_cnt];
            sel = calc_cnt[3:0];
        end else begin
            mac_c = 16'd0;
            sel = 4'd0;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            calc_cnt <= 5'd0;
            mac_valid <= 1'b0;
            mac_clear <= 1'b0;
            shift_en <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tdata <= 16'd0;
            sample_reg <= 16'd0;
        end else begin
            shift_en <= 1'b0; // pulse by default
            
            case (state)
                IDLE: begin
                    mac_valid <= 1'b0;
                    if (s_axis_tvalid && s_axis_tready) begin
                        shift_en <= 1'b1;
                        sample_reg <= s_axis_tdata; // hold for the 16th cycle
                        state <= CALC;
                        calc_cnt <= 5'd0;
                    end
                end
                
                CALC: begin
                    mac_valid <= 1'b1;
                    mac_clear <= (calc_cnt == 5'd1); // clear accumulator on cycle 1
                    
                    if (calc_cnt == 5'd16) begin
                        mac_valid <= 1'b0;
                        mac_clear <= 1'b0;
                        m_axis_tdata <= mac_y; // grab final result
                        m_axis_tvalid <= 1'b1;
                        state <= WAIT_AXI;
                    end else begin
                        calc_cnt <= calc_cnt + 1'b1;
                    end
                end
                
                WAIT_AXI: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        m_axis_tvalid <= 1'b0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
