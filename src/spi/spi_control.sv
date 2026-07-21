module spi_control #(
    parameter CLK_DIV = 4, // clock divider
    parameter DATA_WIDTH = 8
)(
    input logic clk,
    input logic rst_n,
    
    input logic start,
    input logic tx_empty,
    output logic busy,
    
    output logic tx_rd_en,
    output logic rx_wr_en,
    
    output logic load,
    output logic shift_pulse,
    output logic sample_pulse,
    
    // pins out
    output logic sck,
    output logic cs_n
);

    typedef enum logic [1:0] {IDLE, LOAD_ST, ACTIVE, DONE} state_t;
    state_t state, next_state;
    
    logic [$clog2(CLK_DIV)-1:0] clk_cnt;
    logic clk_tick;
    logic sck_int;
    
    // keep track of which bit we are on
    logic [$clog2(DATA_WIDTH):0] bit_cnt; 
    
    assign sck = sck_int;
    
    always_comb begin
        next_state = state;
        tx_rd_en = 1'b0;
        rx_wr_en = 1'b0;
        load = 1'b0;
        cs_n = 1'b0;
        busy = 1'b1;
        
        case (state)
            IDLE: begin
                cs_n = 1'b1;
                busy = 1'b0;
                
                if (start && !tx_empty) begin
                    next_state = LOAD_ST;
                end
            end
            
            LOAD_ST: begin
                tx_rd_en = 1'b1; // grab next byte
                load = 1'b1;     
                next_state = ACTIVE;
            end
            
            ACTIVE: begin
                // wait until the last bit is shifted out on falling edge
                if (bit_cnt == DATA_WIDTH-1 && clk_tick && sck_int == 1'b1) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                rx_wr_en = 1'b1;
                if (!tx_empty) begin
                    next_state = LOAD_ST; 
                end else begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // clock divider counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= '0;
            clk_tick <= 1'b0;
        end else if (state == ACTIVE) begin
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= '0;
                clk_tick <= 1'b1;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
                clk_tick <= 1'b0;
            end
        end else begin
            clk_cnt <= '0;
            clk_tick <= 1'b0;
        end
    end
    
    // toggle the SPI clock
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sck_int <= 1'b0;
        end else if (state == ACTIVE) begin
            if (clk_tick) begin
                sck_int <= ~sck_int;
            end
        end else begin
            sck_int <= 1'b0;
        end
    end
    
    assign sample_pulse = (state == ACTIVE) && clk_tick && (sck_int == 1'b0);
    assign shift_pulse  = (state == ACTIVE) && clk_tick && (sck_int == 1'b1);
    
    // bit counter logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= '0;
        end else if (state == LOAD_ST) begin
            bit_cnt <= '0;
        end else if (state == ACTIVE && clk_tick && sck_int == 1'b1) begin
            bit_cnt <= bit_cnt + 1'b1;
        end
    end

endmodule
