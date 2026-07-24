# Install & quick test

This walks through the RTL-simulation flow and gives a concrete check that it works. It
requires **Siemens QuestaSim** and a **RISC-V GCC** toolchain (see `REQUIREMENTS.md`). No
network access or `make init` is needed — the `main` branch is self-contained.

## 1. Clone and set up the environment

```
git clone git@github.com:Rodolfo-Pellizzoni-Lab/he-soc.git
cd he-soc
source uw_setup.sh
```
A fresh clone lands on `main`, which already has all IP dependencies, VIPs, and the
`bender` binary vendored.

## 2. Generate the QuestaSim compile script

```
cd hardware/
make scripts_vip
```

## 3. Build and run a bring-up test

```
make -C ../software/hello_culsans clean all
make clean sim
```

## Expected output

The simulation boots the cores and prints UART output that ends with a clean
end-of-computation. You should see something like:

```
<!-- paste the actual last ~10 lines of the UART / sim log here, e.g.: -->
<!-- # Mock uart 0: [hello_culsans] ... -->
<!-- # [JTAG] SUCCESS -->
<!-- # ** Note: $finish : .../ariane_tb.sv(...) -->
```

To see the monitoring infrastructure in action, run a PMU/EVU test instead of
`hello_culsans` — for example:

```
make -C ../software/pmu_evu_bench clean all
make clean sim
```
and you should see the PMU/EVU event read-out in the UART log.

> The paper's experiments and case studies were run **on the VCU118 board** using the
> [`apmu-software`](https://github.com/Rodolfo-Pellizzoni-Lab/apmu-software) programs; see
> the main README (*Running on the VCU118 board*) for that flow.
