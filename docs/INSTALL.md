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

The simulation wakes the cores over JTAG, runs the program, and stops at a clean
`$finish`. For `hello_culsans`, the tail of the log looks like:

```
# ** Info: ======== Wait for Completion ========
# Wait EOC...
# Mock uart           0: Hello Culsans! I'm Core 0!
# Mock uart           0: Hello Culsans! I'm Core 1!
# [JTAG] SUCCESS
# ** Note: $finish    : .../hardware/tb/ariane_tb.sv(3739)
#    Time: 6416500 ns  Iteration: 1  Instance: /ariane_tb
```

The **`[JTAG] SUCCESS`** line followed by **`$finish`** confirms the SoC booted, ran, and
completed cleanly. (For the PMU/EVU tests, the UART section instead shows that test's
PMU/EVU read-out before `[JTAG] SUCCESS`.)

Tested with **QuestaSim 2022.4**.

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
