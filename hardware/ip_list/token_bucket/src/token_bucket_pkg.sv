package token_bucket_pkg;
  //Per-core struct. 
  typedef struct packed {
    logic [31:0] token_limit;
    logic [31:0] refill_tokens;
    logic [31:0] refill_interval;
    logic [31:0] aw_cost;
    logic [31:0] ar_cost;
    logic        enable;
  } token_bucket_cfg_t;

endpackage
