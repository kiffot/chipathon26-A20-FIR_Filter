module dual_clock_fifo # (
    parameter DATA_WIDTH = 32,
    parameter DATA_DEPTH = 8,
    parameter ADDR_WIDTH = $clog2(DATA_DEPTH)
) (
    // Read Side Ports
    output logic [ADDR_WIDTH-1:0] rd_count_o,
    output logic [DATA_WIDTH-1:0] rd_data_o,
    output logic                  empty_o,
    output logic                  almost_empty_o,
    input  logic                  rd_en_i,
    input  logic                  rd_clk_i,
    input  logic                  rd_rst_n_i,

    // Write Side Ports
    output logic [ADDR_WIDTH-1:0] wr_count_o,
    output logic                  full_o,
    output logic                  almost_full_o,
    input  logic [DATA_WIDTH-1:0] wr_data_i,
    input  logic                  wr_en_i,
    input  logic                  wr_clk_i,
    input  logic                  wr_rst_n_i
);
    // Memory array
    logic [DATA_WIDTH-1:0] memory [0:DATA_DEPTH-1];

    // Write-side signals
    logic [ADDR_WIDTH:0] read_ptr_gray_sync [2];
    logic [ADDR_WIDTH:0] read_ptr_bin_wr;
    logic [ADDR_WIDTH:0] wr_fill_count;
    logic write_full;
    logic internal_write_enable;
    logic [ADDR_WIDTH:0] write_ptr;
    logic [ADDR_WIDTH:0] write_ptr_gray;

    // Read-side signals
    logic [ADDR_WIDTH:0] write_ptr_gray_sync [2];
    logic [ADDR_WIDTH:0] write_ptr_bin_rd;
    logic [ADDR_WIDTH:0] rd_fill_count;
    logic read_empty;
    logic internal_read_enable;
    logic [ADDR_WIDTH:0] read_ptr;
    logic [ADDR_WIDTH:0] read_ptr_gray;


    // ==========================================
    // WRITE CLOCK DOMAIN
    // ==========================================
    
    always_ff @(posedge wr_clk_i) begin
        if (!wr_rst_n_i) begin
            read_ptr_gray_sync[0] <= 0;
            read_ptr_gray_sync[1] <= 0;
        end else begin
            read_ptr_gray_sync[0] <= read_ptr_gray;
            read_ptr_gray_sync[1] <= read_ptr_gray_sync[0];
        end
    end

    always_comb begin
        read_ptr_bin_wr[ADDR_WIDTH] = read_ptr_gray_sync[1][ADDR_WIDTH];
        for (int i = ADDR_WIDTH-1; i >= 0; i--) begin
            read_ptr_bin_wr[i] = read_ptr_bin_wr[i+1] ^ read_ptr_gray_sync[1][i];
        end
    end

    assign wr_fill_count = write_ptr - read_ptr_bin_wr;
    
    assign write_full    = (write_ptr_gray[ADDR_WIDTH:ADDR_WIDTH-1] == ~read_ptr_gray_sync[1][ADDR_WIDTH:ADDR_WIDTH-1]) && 
                           (write_ptr_gray[ADDR_WIDTH-2:0] == read_ptr_gray_sync[1][ADDR_WIDTH-2:0]);
    
    assign almost_full_o = (wr_fill_count >= (DATA_DEPTH - 1));
    assign full_o        = write_full;

    assign write_ptr_gray        = write_ptr ^ (write_ptr >> 1);
    assign internal_write_enable = wr_en_i & ~write_full;

    always_ff @(posedge wr_clk_i) begin : WRITE_POINTER
        if (!wr_rst_n_i) begin
            write_ptr <= 0;
        end
        else if (internal_write_enable) begin
            memory[write_ptr[ADDR_WIDTH-1:0]] <= wr_data_i;
            write_ptr <= write_ptr + 1;
        end
    end

    assign wr_count_o = write_ptr[ADDR_WIDTH-1:0];


    // ==========================================
    // READ CLOCK DOMAIN
    // ==========================================

    always_ff @(posedge rd_clk_i) begin
        if (!rd_rst_n_i) begin
            write_ptr_gray_sync[0] <= 0;
            write_ptr_gray_sync[1] <= 0;
        end else begin
            write_ptr_gray_sync[0] <= write_ptr_gray;
            write_ptr_gray_sync[1] <= write_ptr_gray_sync[0];
        end
    end

    always_comb begin
        write_ptr_bin_rd[ADDR_WIDTH] = write_ptr_gray_sync[1][ADDR_WIDTH];
        for (int i = ADDR_WIDTH-1; i >= 0; i--) begin
            write_ptr_bin_rd[i] = write_ptr_bin_rd[i+1] ^ write_ptr_gray_sync[1][i];
        end
    end

    assign rd_fill_count  = write_ptr_bin_rd - read_ptr;

    assign read_empty     = (read_ptr_gray == write_ptr_gray_sync[1]); 
    
    assign almost_empty_o = (rd_fill_count <= 1);
    assign empty_o        = read_empty;

    // Pointer logic
    assign read_ptr_gray        = read_ptr ^ (read_ptr >> 1);
    assign internal_read_enable = rd_en_i & ~read_empty;

    always_ff @(posedge rd_clk_i) begin : READ_POINTER
        if (!rd_rst_n_i) begin
            read_ptr  <= 0;
            rd_data_o <= 0;
        end
        else if (internal_read_enable) begin
            rd_data_o <= memory[read_ptr[ADDR_WIDTH-1:0]];
            read_ptr  <= read_ptr + 1;
        end
    end

    assign rd_count_o = read_ptr[ADDR_WIDTH-1:0];

endmodule