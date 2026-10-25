// Minimal stub replacing ariane_soc_pkg.sv.
// Provides only the parameters needed by ariane_axi_soc_pkg.sv.
// Full ariane_soc_pkg.sv depends on ariane_pkg (CVA6 core), which is not
// needed in a standalone slowdown-IP testbench.
//
// Concrete values match the 4-core (QUAD_CORE) he-soc configuration:
//   IdWidth      = 4
//   NrSlaves     = 10  →  $clog2(10) = 4
//   IdWidthSlave = 4 + 4 = 8
//   id_slv_mem_t = logic[8:0]  (9-bit)
// `define QUAD_CORE removed: ariane_axi_soc_pkg.sv now hardcodes UserWidth=2.
package ariane_soc;
    localparam int unsigned IdWidth      = 4;
    localparam int unsigned NrSlaves     = 10;
    localparam int unsigned IdWidthSlave = IdWidth + $clog2(NrSlaves);  // 8
endpackage
