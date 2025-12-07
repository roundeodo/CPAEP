# CPAEP Project
- run tb_one_mac_gemm to execute the top modules
- in our project, M_i, N_i and K_i stand for the number of the block. 
- you can test matrix in different size by modifying these three values. 
- However, the matrix size can be only multiplication of our block size.
- we haven't considered irregular matrix dimension and we haven't developed extra software to do zero padding for irregular matrix dimension. 

# Start
```bash
make TEST_MODULE=tb_one_mac_gemm questasim-run
```
To run with a GUI do:

```bash
make TEST_MODULE=tb_one_mac_gemm questasim-run-gui
```

