// Change the ID width of an AXI request/response pair without any bookkeeping: IDs are zero-extended on the way
// out and truncated on the way back. Only correct when the master's IDs fit in the narrower width (the DMA paths
// into the coherence unit's DMA port, hardware/docs/ethernet.md). Everything else is copied field by field.
module axi_id_width_adapt #(
  parameter type slv_req_t  = logic,
  parameter type slv_resp_t = logic,
  parameter type mst_req_t  = logic,
  parameter type mst_resp_t = logic
) (
  input  slv_req_t  slv_req_i,
  output slv_resp_t slv_resp_o,
  output mst_req_t  mst_req_o,
  input  mst_resp_t mst_resp_i
);
  always_comb begin
    mst_req_o           = '0;
    mst_req_o.aw.id     = slv_req_i.aw.id;
    mst_req_o.aw.addr   = slv_req_i.aw.addr;
    mst_req_o.aw.len    = slv_req_i.aw.len;
    mst_req_o.aw.size   = slv_req_i.aw.size;
    mst_req_o.aw.burst  = slv_req_i.aw.burst;
    mst_req_o.aw.lock   = slv_req_i.aw.lock;
    mst_req_o.aw.cache  = slv_req_i.aw.cache;
    mst_req_o.aw.prot   = slv_req_i.aw.prot;
    mst_req_o.aw.qos    = slv_req_i.aw.qos;
    mst_req_o.aw.region = slv_req_i.aw.region;
    mst_req_o.aw.atop   = slv_req_i.aw.atop;
    mst_req_o.aw.user   = slv_req_i.aw.user;
    mst_req_o.aw_valid  = slv_req_i.aw_valid;
    mst_req_o.w.data    = slv_req_i.w.data;
    mst_req_o.w.strb    = slv_req_i.w.strb;
    mst_req_o.w.last    = slv_req_i.w.last;
    mst_req_o.w.user    = slv_req_i.w.user;
    mst_req_o.w_valid   = slv_req_i.w_valid;
    mst_req_o.b_ready   = slv_req_i.b_ready;
    mst_req_o.ar.id     = slv_req_i.ar.id;
    mst_req_o.ar.addr   = slv_req_i.ar.addr;
    mst_req_o.ar.len    = slv_req_i.ar.len;
    mst_req_o.ar.size   = slv_req_i.ar.size;
    mst_req_o.ar.burst  = slv_req_i.ar.burst;
    mst_req_o.ar.lock   = slv_req_i.ar.lock;
    mst_req_o.ar.cache  = slv_req_i.ar.cache;
    mst_req_o.ar.prot   = slv_req_i.ar.prot;
    mst_req_o.ar.qos    = slv_req_i.ar.qos;
    mst_req_o.ar.region = slv_req_i.ar.region;
    mst_req_o.ar.user   = slv_req_i.ar.user;
    mst_req_o.ar_valid  = slv_req_i.ar_valid;
    mst_req_o.r_ready   = slv_req_i.r_ready;

    slv_resp_o          = '0;
    slv_resp_o.aw_ready = mst_resp_i.aw_ready;
    slv_resp_o.ar_ready = mst_resp_i.ar_ready;
    slv_resp_o.w_ready  = mst_resp_i.w_ready;
    slv_resp_o.b_valid  = mst_resp_i.b_valid;
    slv_resp_o.b.id     = mst_resp_i.b.id;
    slv_resp_o.b.resp   = mst_resp_i.b.resp;
    slv_resp_o.b.user   = mst_resp_i.b.user;
    slv_resp_o.r_valid  = mst_resp_i.r_valid;
    slv_resp_o.r.id     = mst_resp_i.r.id;
    slv_resp_o.r.data   = mst_resp_i.r.data;
    slv_resp_o.r.resp   = mst_resp_i.r.resp;
    slv_resp_o.r.last   = mst_resp_i.r.last;
    slv_resp_o.r.user   = mst_resp_i.r.user;
  end
endmodule
