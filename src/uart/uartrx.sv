`timescale 1ns / 1ps

module uart_rx_coeff_loader #(
    parameter CLKS_PER_BIT = 434
)

(
    input wire  clk,
    input wire  rst,
    input wire  rx_serial,

    output reg [15:0] coeff_data,
    output reg [3:0] coeff_addr,
    output reg [3:0] filter_mode,
    output reg       coeff_valid
);

    localparam s_IDLE           = 3'b000;
    localparam s_RX_START_BIT   = 3'b001;
    localparam s_RX_DATA_BITS   = 3'b010;
    localparam s_RX_STOP_BIT    = 3'b011;
    localparam s_CLEANUP        = 3'b100;

    reg [2:0] r_SM_Main;
    reg [15:0] r_Clock_Count;
    reg [2:0] r_Bit_Index;
    reg [7:0] r_Rx_Byte;
    reg       r_Rx_Data_Valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_SM_Main       <= s_IDLE;
            r_Clock_Count   <= 0;
            r_Bit_Index     <= 0;
            r_Rx_Byte       <= 8'h00;
            r_Rx_Data_Valid <= 1'b0;
        end 
        
        else begin
            case (r_SM_Main)
                s_IDLE: begin
                    r_Rx_Data_Valid <= 1'b0;
                    r_Clock_Count   <= 0;
                    r_Bit_Index     <= 0;

                    if (rx_serial == 1'b0)
                        r_SM_Main     <= s_RX_START_BIT;
                    else
                        r_SM_Main <= s_IDLE;
                end 

                s_RX_START_BIT: begin
                    if (r_Clock_Count == (CLKS_PER_BIT / 2)) begin
                        if (rx_serial == 1'b0) begin
                            r_Clock_Count <= 0;
                            r_SM_Main     <= s_RX_DATA_BITS;
                        end
                        else begin
                            r_SM_Main     <= s_IDLE;
                        end
                    end 
                    else begin
                        r_Clock_Count <= r_Clock_Count + 1;
                        r_SM_Main <= s_RX_START_BIT;
                    end
                end

                s_RX_DATA_BITS: begin
                    if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                        r_Clock_Count <= r_Clock_Count + 1;
                        r_SM_Main     <= s_RX_DATA_BITS;
                    end
                    else begin
                        r_Clock_Count <= 0;
                        r_Rx_Byte[r_Bit_Index] <= rx_serial;

                        if (r_Bit_Index < 7) begin 
                            r_Bit_Index <= r_Bit_Index + 1;
                            r_SM_Main   <= s_RX_DATA_BITS;
                        end
                        else begin
                            r_Bit_Index <= 0;
                            r_SM_Main <= s_RX_STOP_BIT;
                        end
                    end
                end

                s_RX_STOP_BIT: begin
                    if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                        r_Clock_Count <= r_Clock_Count + 1;
                        r_SM_Main     <= s_RX_STOP_BIT;
                    end
                    else begin
                        r_Rx_Data_Valid <= 1'b1;
                        r_Clock_Count <= 0;
                        r_SM_Main <= s_CLEANUP;
                    end
                end

                s_CLEANUP: begin
                    r_Rx_Data_Valid <= 1'b0;
                    r_SM_Main       <= s_IDLE;
                end

                default: r_SM_Main <= s_IDLE;
            endcase
        end
    end

    reg [1:0] byte_count;
    reg [15:0] temp_coeff_data;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            byte_count      <= 2'd0;
            temp_coeff_data <= 16'h0000;
            coeff_data      <= 16'h0000;
            coeff_addr      <= 4'h0;
            filter_mode     <= 4'h0;
            coeff_valid     <= 1'b0;
        end
        else begin
            coeff_valid <= 1'b0;

            if (r_Rx_Data_Valid) begin
                case (byte_count)
                    2'd0: begin
                        temp_coeff_data[7:0] <= r_Rx_Byte;
                        byte_count           <= byte_count + 1;
                    end

                    2'd1: begin
                        temp_coeff_data[15:8]   <= r_Rx_Byte;
                        byte_count              <= byte_count + 1;
                    end

                    2'd2: begin
                        coeff_data  <= temp_coeff_data;
                        coeff_addr  <= r_Rx_Byte[7:4];
                        filter_mode <= r_Rx_Byte[3:0];

                        coeff_valid <= 1'b1;
                        byte_count  <= 2'd0;
                    end

                    default: byte_count <= 2'd0;
                endcase
            end
        end
    end
endmodule
