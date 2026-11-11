package tb_pkg;

  import "DPI-C" \time = function int _time (inout int tloc[4]);
  import "DPI-C" function string ctime(inout int tloc[4]);

  time CLK_HI     = 5ns;
  time CLK_LO     = 5ns;
  time CLK_PERIOD = CLK_HI + CLK_LO;
  time APPL_DEL   = 2ns;
  time ACQ_DEL    = 8ns;

  parameter ERROR_CNT_STOP_LEVEL = 0;

  class progress;
    real    newState, oldState;
    longint numResp, acqCnt, errCnt, totAcqCnt, totErrCnt;
    string  name;

    function new(string name);
      this.name      = name;
      this.acqCnt    = 0;
      this.errCnt    = 0;
      this.newState  = 0.0;
      this.oldState  = 0.0;
      this.numResp   = 1;
      this.totAcqCnt = 0;
      this.totErrCnt = 0;
    endfunction

    function void reset(longint numResp_);
      this.acqCnt   = 0;
      this.errCnt   = 0;
      this.newState = 0.0;
      this.oldState = 0.0;
      this.numResp  = numResp_;
    endfunction

    function void addRes(int isError);
      this.acqCnt++;
      this.totAcqCnt++;
      this.errCnt    += isError;
      this.totErrCnt += isError;
      if (ERROR_CNT_STOP_LEVEL > 0 && ERROR_CNT_STOP_LEVEL <= this.errCnt) begin
        $error("%s> stopping at ERROR_CNT_STOP_LEVEL=%0d", this.name, ERROR_CNT_STOP_LEVEL);
        $stop();
      end
    endfunction

    function void print();
      this.newState = $itor(this.acqCnt) / $itor(this.numResp);
      if (this.newState - this.oldState >= 0.01) begin
        $display("%s> validated %03d%% -- %01d failed (%03.3f%%)",
          this.name,
          $rtoi(this.newState * 100.0),
          this.errCnt,
          $itor(this.errCnt) / $itor(this.acqCnt) * 100.0);
        this.oldState = this.newState;
      end
    endfunction

    function void printToFile(string file, bit summary = 0);
      int fptr;
      fptr = $fopen(file, "w");
      if (summary) begin
        $fdisplay(fptr, "Simulation Summary of %s", this.name);
        $fdisplay(fptr, "total: %01d of %01d vectors failed", this.totErrCnt, this.totAcqCnt);
        $fdisplay(fptr, this.totErrCnt == 0 ? "CI: PASSED" : "CI: FAILED");
      end
      $fclose(fptr);
    endfunction

  endclass

endpackage
