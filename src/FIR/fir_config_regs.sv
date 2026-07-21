module fir_config_regs (
    input  logic        clk,
    input  logic        rst_n,
    
    // from UART
    input  logic [15:0] coeff_data,
    input  logic [3:0]  coeff_addr,
    input  logic [3:0]  filter_mode,
    input  logic        coeff_valid,
    
    // to Datapath
    output logic [15:0] coeff_mem [0:15],
    output logic        mode_odd,
    output logic        mode_asym
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_odd <= 1'b0;
            mode_asym <= 1'b0;
            for (int i = 0; i < 16; i++) begin
                coeff_mem[i] <= 16'd0;
            end
        end else if (coeff_valid) begin
            if (filter_mode[3] == 1'b1) begin
                // 1xxx: Write Coefficient
                coeff_mem[coeff_addr] <= coeff_data;
            end else if (filter_mode == 4'b0100) begin
                // 0100: Even Symmetric
                mode_odd <= 1'b0;
                mode_asym <= 1'b0;
            end else if (filter_mode == 4'b0101) begin
                // 0101: Odd Symmetric
                mode_odd <= 1'b1;
                mode_asym <= 1'b0;
            end else if (filter_mode[3:1] == 3'b011) begin
                // 011x: Asymmetric
                mode_odd <= 1'b0;
                mode_asym <= 1'b1;
            end
        end
    end

endmodule
