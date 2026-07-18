module mac (
    input logic clk,
    input logic rst_n,
    input logic valid,
    input logic clear,
    input logic signed [15:0] x,
    input logic signed [15:0] c,

    output logic signed [15:0] y,
    output logic done
);

logic signed [31:0] product;
logic signed [36:0] accumulator;

always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)begin
        product <= '0;
        accumulator <= '0;
        y <= '0;
        done <= 1'b0;
    end else begin
        if (valid) begin
            product <= x*c;
        if (clear) begin
            accumulator <= 37'(product);
        end else begin
            accumulator <= accumulator + 37'(product);
        end
        y <= accumulator[30:15];
        done <= 1'b1;
    end else begin
        done <= 1'b0;
    end
    
    end
endmodule