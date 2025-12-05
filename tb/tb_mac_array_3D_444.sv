module tb_mac_array_3D_444;
    parameter int unsigned InDataWidth = 8;
    parameter int unsigned OutDataWidth = 32;
    parameter int unsigned meshRow = 4;
    parameter int unsigned meshCol = 4;
    parameter int unsigned tileSize = 4;
    parameter int unsigned NumTests = 10;
    parameter int unsigned M_block = 1;
    parameter int unsigned N_block = 4;
    parameter int unsigned K_block = 16;

    localparam int unsigned total_row = M_block * meshRow;
    localparam int unsigned total_col = N_block * meshCol;
    localparam int unsigned total_k   = K_block * tileSize;

    logic clk_i;
    logic rst_ni;
    logic signed [meshRow-1:0][tileSize-1:0][InDataWidth-1:0] a_i;
    logic signed [meshCol-1:0][tileSize-1:0][InDataWidth-1:0] b_i;
    logic a_valid_i;
    logic b_valid_i;    
    logic init_save_i;
    logic acc_clr_i;

    logic signed [meshRow-1:0][meshCol-1:0][OutDataWidth-1:0] c_o;
    logic signed [total_row-1:0][total_col-1:0][OutDataWidth-1:0] golden_c_o;

    logic signed [InDataWidth-1:0] A_mem [total_row][total_k];
    logic signed [InDataWidth-1:0] B_mem [total_col][total_k];
    logic signed [OutDataWidth-1:0] Y_mem [total_row][total_col];

    mac_array_3D_444 #(
        .InDataWidth ( InDataWidth ),
        .OutDataWidth( OutDataWidth),
        .meshRow     ( meshRow     ),
        .meshCol     ( meshCol     ),
        .tileSize    ( tileSize    )
    ) i_dut (
        .clk_i       ( clk_i       ),
        .rst_ni      ( rst_ni      ),
        .a_i         ( a_i         ),
        .b_i         ( b_i         ),
        .a_valid_i   ( a_valid_i   ),
        .b_valid_i   ( b_valid_i   ),
        .init_save_i ( init_save_i ),
        .acc_clr_i   ( acc_clr_i   ),
        .c_o         ( c_o         )
    );

    `include "includes/common_tasks.svh"

    function automatic void mac_array_3D_444_golden();
        integer i, j, k;
        for(i = 0; i < total_row; i = i + 1) begin
            for(j = 0; j < total_col; j = j + 1) begin
                golden_c_o[i][j] = '0;
            end
        end

        for (i = 0; i < total_row; i = i + 1) begin
            for(j = 0; j < total_col; j = j + 1) begin
                for(k = 0; k < total_k; k = k + 1) begin
                    golden_c_o[i][j] = ($signed(golden_c_o[i][j]) + ($signed(A_mem[i][k]) * $signed(B_mem[j][k])));
                end
            end
        end
    endfunction

    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;  // 100MHz clock
    end

    initial begin
        clk_i      = 1'b0;
        rst_ni     = 1'b0;
        a_valid_i  = 1'b0;
        b_valid_i  = 1'b0;
        init_save_i= 1'b0;
        acc_clr_i  = 1'b0;

        // Initialize inputs
        for (int i = 0; i < meshRow; i++) begin
            for (int j = 0; j < tileSize; j++) begin
                a_i[i][j] = '0;
                clk_delay(1);
            end
        end
        for (int i = 0; i < meshCol; i++) begin
            for (int j = 0; j < tileSize; j++) begin
                b_i[i][j] = '0;
                clk_delay(1);
            end
        end

        clk_delay(3);
        #1;
        rst_ni = 1'b1;

        clk_delay(1);

        //driver logic
        for(int num = 0; num < NumTests; num = num + 1) begin
            //genereate random data in memory
            for(int r = 0; r < total_row; r = r + 1) begin
                for(int k = 0; k < total_k; k = k + 1) begin
                    A_mem[r][k] = $urandom;
                end
            end

            for(int c = 0; c < total_col; c = c + 1) begin
                for(int k = 0; k < total_k; k = k + 1) begin
                    B_mem[c][k] = $urandom;
                end
            end

            //Calculate golden value
            mac_array_3D_444_golden();

            clk_delay(5);

            $display("starting hardware execution for test %0d", num);
            //hardware execution
            for (int m = 0; m < M_block; m = m + 1) begin
                for(int n = 0; n < N_block; n = n + 1) begin
                    $display("Processing block M %0d, N %0d", m, n);
                    for(int k = 0; k < K_block; k = k + 1) begin
                        @(negedge clk_i);
                        a_valid_i   = 1'b1;
                        b_valid_i   = 1'b1;
                        if(k == 0) 
                            init_save_i = 1'b1;
                        else 
                            init_save_i = 1'b0;
                        
                        //load A
                        for(int r = 0; r < meshRow; r = r + 1) begin
                            for(int t = 0; t < tileSize; t = t + 1) begin
                                a_i[r][t] = A_mem[m*meshRow + r][k*tileSize + t];
                            end
                        end
                        //load B
                        for(int c = 0; c < meshCol; c = c + 1) begin
                            for(int t = 0; t < tileSize; t = t + 1) begin
                                b_i[c][t] = B_mem[n*meshCol + c][k*tileSize + t];
                            end
                        end
                    clk_delay(1);    
                        // //debug A
                        // for(int r = 0; r < meshRow; r = r + 1) begin
                        //     for(int t = 0; t < tileSize; t = t + 1) begin
                        //         $display("for block_M[%0d] block_K[%0d] A[%0d][%0d] = %0d",m,k, r, t, $signed(a_i[r][t]));
                        //     end
                        // end
                        // //debug B
                        // for(int c = 0; c < meshCol; c = c + 1) begin
                        //     for(int t = 0; t < tileSize; t = t + 1) begin
                        //         $display("for block_N[%0d] block_K[%0d] B[%0d][%0d] = %0d",n,k, c, t, $signed(b_i[c][t]));
                        //     end
                        // end
                        // //display output c_o
                        // for(int r = 0; r < meshRow; r = r + 1) begin
                        //     for(int c = 0; c < meshCol; c = c + 1) begin
                        //         $display("for block_M[C[%0d][%0d] = %0d", r, c, $signed(c_o[r][c]));
                        //     end
                        // end
                    //if(k == 4)$finish;
                    end//complete k block
                    @(posedge clk_i);
                    a_valid_i   = 1'b0;
                    b_valid_i   = 1'b0;
                    init_save_i = 1'b0;
                    for(int r = 0; r < meshRow; r = r + 1) begin
                        for(int c = 0; c < meshCol; c = c + 1) begin
                            int global_c;
                            int global_r;
                            global_r = m*meshRow + r;
                            global_c = n*meshCol + c;

                            if(c_o[r][c] !== golden_c_o[global_r][global_c]) begin
                                $display("Error in test %0d, block M %0d, N %0d,EXPECTED %0d, GOT %0d",
                                    num, m, n,
                                    $signed(golden_c_o[global_r][global_c]),
                                    $signed(c_o[r][c]));
                                $fatal;
                            end
                        end
                    end
                    $display("Block M %0d, N %0d passed.", m, n);
                end
            end
            $display("Completed all blocks for test %0d", num);
        end
    clk_delay(5);
    $display("All tests passed.");
    $finish;
    end
endmodule