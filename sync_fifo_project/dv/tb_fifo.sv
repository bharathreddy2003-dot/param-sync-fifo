`timescale 1ns/1ps

module tb_fifo();

    // =========================================================================
    // Parameters & Signals
    // =========================================================================
    localparam DATA_WIDTH = 8;
    localparam FIFO_DEPTH = 16;
    
    logic clk;
    logic rst_n;
    logic w_en;
    logic r_en;
    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;
    logic full, empty, almost_full, almost_empty;

    // Golden Reference Model (SystemVerilog Queue)
    logic[DATA_WIDTH-1:0] golden_queue [$];
    logic [DATA_WIDTH-1:0] expected_data;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .* // Implicit port connection
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // =========================================================================
    // Verification Tasks
    // =========================================================================
    task apply_reset();
        rst_n = 0;
        w_en = 0;
        r_en = 0;
        data_in = 0;
        @(posedge clk);
        @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset De-asserted", $time);
    endtask

    task write_fifo(input logic[DATA_WIDTH-1:0] w_data);
        @(posedge clk);
        if (!full) begin
            w_en = 1;
            data_in = w_data;
            golden_queue.push_back(w_data);
            $display("[%0t] WRITE: %h", $time, w_data);
        end else begin
            $display("[%0t] WRITE DROP (FULL): %h", $time, w_data);
            w_en = 1; // Assert anyway to test corner case (should not corrupt)
        end
        @(posedge clk);
        w_en = 0;
    endtask

    task read_fifo();
        @(posedge clk);
        if (!empty) begin
            r_en = 1;
            expected_data = golden_queue.pop_front();
            @(posedge clk); // Wait for registered output
            r_en = 0;
            // Self-checking assertion
            if (data_out !== expected_data) begin
                $error("[%0t] READ FAIL: Expected %h, Got %h", $time, expected_data, data_out);
            end else begin
                $display("[%0t] READ PASS: %h", $time, data_out);
            end
        end else begin
            $display("[%0t] READ DROP (EMPTY)", $time);
            r_en = 1; // Assert to test corner case
            @(posedge clk);
            r_en = 0;
        end
    endtask

    // =========================================================================
    // Main Stimulus Sequence
    // =========================================================================
    initial begin
        $display("Starting FIFO Verification...");
        apply_reset();

        // 1. Fill the FIFO to check full and almost_full flags
        for (int i=0; i < FIFO_DEPTH + 2; i++) begin
            write_fifo($urandom_range(0, 255));
        end

        // 2. Read back half of the elements
        for (int i=0; i < FIFO_DEPTH/2; i++) begin
            read_fifo();
        end

        // 3. Simultaneous Read and Write
        fork
            write_fifo(8'hAA);
            read_fifo();
        join

        // 4. Empty the FIFO
        for (int i=0; i < (FIFO_DEPTH/2) + 2; i++) begin
            read_fifo();
        end
        
        $display("Verification Complete!");
        $finish;
    end

endmodule