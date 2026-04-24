module s27ks0641_bmod_wrapper (
   // Inouts
   dq, rwds,
   // Inputs
   cs_n, ck, ck_n, hwreset_n
   );
   input cs_n;
   input ck;
   input ck_n;
   input hwreset_n;
   inout [7:0] dq;
   inout       rwds;

   s27ks0641 #(.TimingModel("S27KS0641DPBHI020"))
     s27ks0641 (/*AUTOINST*/
		// Inouts
		.DQ7			(dq[7]),		 // Templated
		.DQ6			(dq[6]),		 // Templated
		.DQ5			(dq[5]),		 // Templated
		.DQ4			(dq[4]),		 // Templated
		.DQ3			(dq[3]),		 // Templated
		.DQ2			(dq[2]),		 // Templated
		.DQ1			(dq[1]),		 // Templated
		.DQ0			(dq[0]),		 // Templated
		.RWDS			(rwds),			 // Templated
		// Inputs
		.CSNeg			(cs_n),			 // Templated
		.CK			(ck),			 // Templated
		.CKNeg			(ck_n),			 // Templated
		.RESETNeg		(hwreset_n));		 // Templated

   initial begin
        automatic string sdf_file_path = "../ips/models/s27ks0641/s27ks0641.sdf";
        $sdf_annotate("../ips/models/s27ks0641/s27ks0641.sdf");
        $display ("%s[TB - S27KS0641 HYPERMEM] %s%t - %sSDF annotation with %s%s", "\x1B[1;34m", "\x1B[0;37m", $time, "\x1B[0;35m", sdf_file_path , "\x1B[0m");
   end
endmodule
