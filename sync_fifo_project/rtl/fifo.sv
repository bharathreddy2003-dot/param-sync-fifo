`timescale 1ns/1ps

module fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16, // Must be a power of 2
    parameter ALMOST_FULL_THRESH = 2,
    parameter ALMOST_EMPTY_THRESH = 2
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    w_en,
    input  logic                    r_en,
    input  logic [DATA_WIDTH-1:0]   data_in,
    output logic[DATA_WIDTH-1:0]   data_out,
    output logic                    full,
    output logic                    empty,
    output logic                    almost_full,
    output logic                    almost_empty
);

    // =========================================================================
    // Parameter Validations & Localparams
    // =========================================================================
    // PTR_WIDTH is the number of bits required to address the memory.
    localparam PTR_WIDTH = $clog2(FIFO_DEPTH);
    
    // =========================================================================
    // Internal Signals
    // =========================================================================
    // Memory Array (Inference for Block RAM or Register File)
    logic[DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    // Pointers are N+1 bits wide to distinguish between Full and Empty conditions.
    // The MSB acts as a "wrap-around" flag.
    logic [PTR_WIDTH:0] wr_ptr, rd_ptr;
    logic[PTR_WIDTH:0] wr_ptr_nxt, rd_ptr_nxt;
    
    // Number of elements currently in the FIFO
    logic [PTR_WIDTH:0] count_nxt;

    // =========================================================================
    // Next-State Pointer Logic (Look-Ahead)
    // =========================================================================
    // We calculate the next state combinationally so we can strictly register 
    // the status flags (full/empty), preventing combinational glitches.
    assign wr_ptr_nxt = wr_ptr + (w_en && !full);
    assign rd_ptr_nxt = rd_ptr + (r_en && !empty);
    
    // Count calculation for almost_full / almost_empty flags
    assign count_nxt = wr_ptr_nxt - rd_ptr_nxt;

    // =========================================================================
    // Sequential Logic (Memory Write & Pointers)
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
        end else begin
            wr_ptr <= wr_ptr_nxt;
            rd_ptr <= rd_ptr_nxt;
        end
    end

    // Memory Write (Synchronous)
    always_ff @(posedge clk) begin
        if (w_en && !full) begin
            mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in;
        end
    end

    // Memory Read & Output Registering (Synchronous)
    // Note: This introduces a 1-cycle latency for data_out (Standard Sync FIFO)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= '0;
        end else if (r_en && !empty) begin
            data_out <= mem[rd_ptr[PTR_WIDTH-1:0]];
        end
    end

    // =========================================================================
    // Output Flags (Strictly Registered)
    // =========================================================================
    /*
     * POINTER LOGIC EXPLANATION:
     * - EMPTY: Both pointers are exactly equal (same address, same wrap MSB).
     * - FULL: The lower bits (address) are identical, but the MSB (wrap bit) 
     *         is inverted. This means the write pointer has wrapped exactly 
     *         one full time ahead of the read pointer.
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            full         <= 1'b0;
            empty        <= 1'b1;
            almost_full  <= 1'b0;
            almost_empty <= 1'b1;
        end else begin
            full         <= (wr_ptr_nxt[PTR_WIDTH] != rd_ptr_nxt[PTR_WIDTH]) && 
                            (wr_ptr_nxt[PTR_WIDTH-1:0] == rd_ptr_nxt[PTR_WIDTH-1:0]);
            
            empty        <= (wr_ptr_nxt == rd_ptr_nxt);
            
            almost_full  <= (count_nxt >= (FIFO_DEPTH - ALMOST_FULL_THRESH));
            almost_empty <= (count_nxt <= ALMOST_EMPTY_THRESH);
        end
    end

endmodule
