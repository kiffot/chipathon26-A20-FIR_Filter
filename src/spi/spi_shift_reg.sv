module spi_shift_reg #(
    parameter DATA_WIDTH = 8
)(
    input logic clk,
    input logic rst_n,
    
    input logic load,
    input logic shift, 
    input logic sample, 
    
    input logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout,
    
    input logic miso,
    output logic mosi
);

    logic [DATA_WIDTH-1:0] shift_reg;
    logic sampled_miso;
    
    assign mosi = shift_reg[DATA_WIDTH-1];
    assign dout = shift_reg;
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= '0;
            sampled_miso <= 1'b0;
        end else begin
            if (load) begin
                shift_reg <= din;
            end else begin
                // grab miso on rising edge
                if (sample) begin
                    sampled_miso <= miso;
                end
                
                // shift out on falling edge
                if (shift) begin
                    shift_reg <= {shift_reg[DATA_WIDTH-2:0], sampled_miso};
                end
            end
        end
    end

endmodule
