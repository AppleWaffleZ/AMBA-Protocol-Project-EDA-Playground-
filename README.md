# AXI4-Lite UVM Testbench

A working UVM testbench for a 4-register AXI4-Lite slave, organized into
packages, with randomized stimulus, a checking scoreboard, and a
functional coverage collector. Built and debugged interactively on
[EDA Playground](https://www.edaplayground.com/) (VCS + UVM 1.2).

## Files

| File | Role |
|---|---|
| `design.sv` | DUT - AXI4-Lite slave, 4 x 32-bit registers at `0x00/0x04/0x08/0x0C`, `SLVERR` for anything else |
| `if.sv` | Interface bundling all 5 AXI4-Lite channels (lives outside both packages - interfaces can't go inside a `package`) |
| `axi4lite_pkg.sv` | Package holding every reusable testbench class (agent, driver, monitor, scoreboard, coverage, env, sequence) |
| `test_pkg.sv` | Package holding only the test class - depends on `axi4lite_pkg`, one-directional |
| `sequence_item.sv` | One write or read transaction (`axi4lite_seq_item`) - address is fully random, no range constraint |
| `sequencer.sv` | `axi4lite_sequencer` typedef |
| `driver.sv` | Drives pins from sequence items; waits for reset before driving anything |
| `monitor.sv` | Observes the bus; publishes both writes (paired with real `BRESP`) and reads (paired with real `RRESP`) |
| `write_read_transaction_seq.sv` | Randomizes `num_transactions` write+read pairs across the full address range |
| `agent.sv` | Bundles driver + sequencer + monitor |
| `scoreboard.sv` | Models last-written value per address, checks response codes and read data, SLVERR-aware |
| `addr_coverage.sv` | Second subscriber on the monitor's analysis port - tracks which addresses were exercised |
| `env.sv` | Wires agent + scoreboard + coverage together |
| `axi4lite_base_test.sv` | Runs the sequence |
| `testbench.sv` | `` `include``s both packages directly (order-independent), imports them, defines the top module |

## How to run on EDA Playground

1. Design pane: paste `design.sv`.
2. Testbench pane: create one tab per file above, named exactly as
   listed - `` `include`` statements reference these names literally.
3. UVM/OVM dropdown: set to a real version (e.g. 1.2).
4. Simulator: **VCS** confirmed working. Questa has been observed to
   hang/get killed (exit 137) during its DPI auto-compile step on some
   EDA Playground server instances - a known platform issue, not a bug
   here. Switch simulators if you hit that.
5. Check **"Open EPWave after run"** for a waveform.
6. Run.

Because `testbench.sv` pulls in both packages via `` `include`` (not
relying on `import` + tab ordering), **tab display order in EDA
Playground doesn't matter** for this project - unlike an earlier version
of this project, which broke when `testbench.sv`'s tab happened to sit
before the package tabs it needed to `import`.

## Why packages, not a flat `` `include`` chain

Earlier versions of this project had every class file `` `include``'d
directly into `testbench.sv`, in careful dependency order. That works,
but it isn't how real UVM codebases are structured - production code
uses actual `import`-based packages, which gives real namespacing (no
class-name collisions across unrelated testbenches), reusability
(`import axi4lite_pkg::*;` into a totally different top-level testbench
reuses the agent/driver/monitor as-is), and matches what real commercial
VIP looks like.

**Every file that uses `` `uvm_info``/`` `uvm_fatal`` or references UVM
base classes still needs its own `import uvm_pkg::*;` and
`` `include "uvm_macros.svh" ``** - `import` doesn't chain through nested
package imports automatically. That's why both `axi4lite_pkg.sv` and
`test_pkg.sv` each repeat these lines rather than assuming one covers
the other.

## What a passing run looks like

Since the sequence now randomizes addresses across the full `0x00`-`0xFF`
range and the DUT only implements `0x00`-`0x0F`, expect a genuine mix of
outcomes per run:

```
UVM_INFO ... [write_read_transaction_seq] WRITE addr=0x4 data=0x9a3c1f02 -> resp=0
UVM_INFO ... [write_read_transaction_seq] READ  addr=0x4 <- data=0x9a3c1f02 resp=0
UVM_INFO ... [write_read_transaction_seq] WRITE addr=0x7a data=0x1145de00 -> resp=2
UVM_INFO ... [write_read_transaction_seq] READ  addr=0x7a <- data=0x00000000 resp=2
...
UVM_INFO scoreboard.sv ... [SCBD] Scoreboard summary: N checks passed, 0 errors
UVM_INFO addr_coverage.sv ... [COV] Distinct addresses exercised: M
UVM_INFO addr_coverage.sv ... [COV] Addresses: 0x4 0x7a ...
```

`resp=2` (`SLVERR`) on out-of-range addresses is expected and correct,
not a failure - the scoreboard checks the response code itself and
only compares read data against the model for addresses it expects to
be valid (see "How the pieces fit together" below).

## How the pieces fit together (the non-obvious parts)

**Reset synchronization.** The driver explicitly waits for `ARESETn` to
go high before driving anything (`driver.sv`), and `AWREADY`/`ARREADY`
in the DUT are gated with `!ARESETn` (`design.sv`). Without both, the
first write handshake can appear to "complete" combinationally while
still in reset, the driver drops `AWVALID`/`WVALID` believing it
succeeded, and then waits forever for a `BVALID` that can never arrive -
a real reset-timing deadlock this project hit and fixed.

**Write and read response pairing in the monitor.** Neither `BRESP` nor
`RRESP` is known at the same beat as the address/data handshake - both
arrive one cycle later. `monitor.sv` handles this with two small queues
(`aw_pend_q` for writes, `ar_addr_q` for reads): push address(+data) when
the address/data handshake completes, pop and pair with the real
response code when `B`/`R` actually arrives.

**Scoreboard is SLVERR-aware.** `scoreboard.sv` computes the expected
response for every transaction based on the DUT's own address decode
rule (`addr[7:4] == 0`), checks the actual response against it, and only
updates/compares its write-model for addresses that should have
succeeded - so out-of-range accesses are verified on their response
code, not incorrectly flagged as data mismatches.

**`uvm_analysis_port` is one-to-many.** `addr_coverage.sv` is a second,
completely independent subscriber connected to the exact same
`agent.mon.ap` the scoreboard uses (see `env.sv`'s `connect_phase`).
`monitor.sv` has no idea this class exists - proof that the monitor's
job (observe and publish) is fully decoupled from how many things react
to what it publishes.

**Randomization.** `sequence_item.sv`'s address constraint is removed,
so `addr` randomizes across all 256 values. `write_read_transaction_seq.sv`
constrains each read to the same address it just wrote
(`addr == wr.addr`) so the scoreboard always has something meaningful to
check - removing that constraint would give fully independent random
reads, at the cost of frequent "no prior write observed" scoreboard
warnings.

## Known simplifications / good next extensions

1. **`WSTRB` is driven (always `4'hF`) but never checked by the DUT** -
   a spec-compliant slave should only update byte lanes whose strobe bit
   is set.
2. **Only one transaction outstanding at a time** - no pipelining, no
   ID-based out-of-order completion (AXI4-Lite has no ID fields at all).
3. **No `uvm_config_db` config object yet** - toggling the scoreboard or
   coverage collector on/off currently means editing `env.sv` directly,
   rather than a config object set from the test.
4. **No factory overrides** - bugs have been injected so far by directly
   editing `design.sv`/`monitor.sv`, not by overriding a component from
   the test via the factory (`set_type_override_by_type`).
5. **This is AXI4-Lite, not full AXI4** - no bursts, no IDs, no exclusive
   access. Extending to a burst-capable, ID-tagged full AXI4 slave is the
   natural "next tier," and would need the monitor's queue-based pairing
   pattern extended to be keyed by ID rather than assuming one
   transaction at a time.
