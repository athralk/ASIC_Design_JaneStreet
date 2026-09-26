# eth10t on the Arty A7: using the board's own Ethernet port

> **Status: stopped, not working on hardware.** It builds, loads, links, and passes all simulations (§10), but on the real board no frames get through. See §12 for what happened and the next step.

The cable goes into **the Arty's built-in RJ45 port**. No extra hardware, no Pmod wiring.

---

## 1. The idea in one picture

```
 PC ──RJ45 cable──► DP83848 PHY chip ──MII (4-bit nibbles)──► MII bridge ──TD+/TD-, RD──► eth10t chip + demo host
  (on the Arty board)                ◄──MDIO (config)────────── MDIO init       (Manchester)   (same logic as the TinyTapeout tile)
                                                               └──────────── all inside the FPGA ────────────┘
```

The eth10t chip is **exactly the logic that goes on the TinyTapeout silicon**. It speaks raw Manchester line signals: TD+/TD- out, RD in. The Arty's RJ45 port is not wired to the FPGA; it is wired to a separate PHY chip. So we add a small **bridge** in the FPGA that translates between the two.

---

## 2. Background: PHY, MII, MDIO

### What a PHY is
An Ethernet interface has two halves:

| Part | Job | In our project |
|---|---|---|
| **MAC** (media access control) | Frames: preamble, addresses, padding, CRC, collisions | `tx.ml` / `rx.ml` framing |
| **PHY** (physical layer) | Turns bits into the analog cable signal and back: Manchester coding, link pulses, clock recovery | `tx.ml` Manchester encoder, `rx.ml` digital PLL |

**Our chip contains both halves.** The Arty has its own PHY chip, a **TI DP83848**, between the FPGA and the jack. The only way into the jack is through that chip.

### What MII is
MII (Media Independent Interface) is the standard wire bundle between a MAC and a PHY chip. At 10 Mb/s:

| Signal | Direction | Meaning |
|---|---|---|
| `TX_CLK` | PHY → FPGA | 2.5 MHz clock. We change `TXD`/`TX_EN` after its rising edge. |
| `TXD[3:0]` | FPGA → PHY | 4 bits (one *nibble*) per `TX_CLK` cycle. `TXD[0]` is sent on the wire first. |
| `TX_EN` | FPGA → PHY | High for every nibble of a frame, from preamble to the last FCS nibble |
| `RX_CLK` | PHY → FPGA | 2.5 MHz clock recovered from the incoming signal |
| `RXD[3:0]` | PHY → FPGA | Received nibble, valid on `RX_CLK` rising edge |
| `RX_DV` | PHY → FPGA | High while a received frame is on `RXD` |

4 bits × 2.5 MHz = 10 Mb/s. On MII the MAC sends **the preamble and SFD too**: `0x5` nibbles, then `0xD`.

### What MDIO is
MDIO is a slow two-wire management bus: `MDC` is the clock and `MDIO` is bidirectional data. The FPGA uses it to write the PHY's configuration registers. One write is a 64-bit frame:

```
32 × '1' (preamble) | 01 (start) | 01 (write) | PHYAD (5 bits) | REG (5 bits) | 10 (turnaround) | DATA (16 bits)
```

The Arty's DP83848 answers at **PHY address 1**.

### Why MDIO is needed at all
Left alone, the DP83848 negotiates **100 Mb/s** with a modern PC. Our chip is a 10 Mb/s design, so at power-up the FPGA writes two registers:

| Register | Value | Effect |
|---|---|---|
| 4 (ANAR, auto-negotiation advertisement) | `0x0021` | "I only support 10BASE-T half duplex" |
| 0 (BMCR, basic control) | `0x1200` | Auto-negotiation on, restart it now |

The PC then agrees on **10 Mb/s half duplex**, which is exactly what our chip does.

---

## 3. How the bridge works (`hardcaml/lib/mii_bridge.ml`)

Everything runs on one 60 MHz clock. The slow MII clocks (2.5 MHz, 24 of our cycles per period) are treated as *data*: synchronised, then edge-detected.

### Transmit: our Manchester → MII nibbles
1. **Decode our own line.** TD+/TD- come from our chip on the same clock, so they are perfectly clean.
   - A frame starts when TD- goes high. The first half of the first preamble bit is "low", which is TD-.
   - From then on, every bit lasts exactly 6 cycles. The bridge reads the bit from TD+ in the middle of its second half.
2. **Find the end.** A bit whose two halves are equal has no mid-bit transition, so it isn't data. That's TP_IDL (the end-of-frame idle), and the frame is over.
3. **Drop link pulses.** A lone TD+ pulse with no TD- is a link pulse. The DP83848 makes its own, so ours are not forwarded.
4. **Pack into nibbles.** The first bit goes to `TXD[0]`. Nibbles go into a small FIFO (first-in, first-out buffer).
5. **Send on MII.** On every `TX_CLK` rising edge, the next nibble goes out with `TX_EN` = 1, until the FIFO is empty at frame end.

**Why the FIFO never runs dry mid-frame.** The DP83848's clock comes from the FPGA: we give it 25 MHz on `ETH_REF_CLK`, made by the same MMCM that makes our 60 MHz. Its 2.5 MHz `TX_CLK` is therefore locked to our clock, and nibbles go out exactly as fast as our chip makes them.

### Receive: MII nibbles → our Manchester
1. **Collect nibbles.** On each `RX_CLK` rising edge while `RX_DV` = 1, store `RXD` in a FIFO. `RXD` is taken from just *before* the edge, where MII guarantees it is stable.
2. **Add a short preamble.** At the start of each frame, the bridge first emits 16 bits of `1010…`. That gives our receiver a guaranteed lock-in, and lets 4 nibbles build up in the FIFO.
3. **Serialise and encode.** It sends bit after bit, `RXD[0]` first, as Manchester onto the chip's `RD` input at exactly 6 cycles per bit: first half the complement, second half the bit.
4. **Drop the echo.** In 10 Mb/s half duplex, the PHY copies everything we transmit back onto `RXD` (the 802.3 "10BASE-T loopback"). Our chip would take that echo for another station talking and declare a collision. So any frame that *starts while we are transmitting* is dropped by the bridge.
5. **The chip does the rest.** Its digital PLL locks, it finds the SFD, assembles bytes and checks the CRC, exactly as it would on a real cable.

**Why a 4-nibble buffer is enough.** `RX_CLK` follows the PC's clock, which can differ from ours by up to ±100 ppm (parts per million). Over the longest frame (12,144 bits) that's at most about 1.2 bits of drift, far less than the 16-bit head start.

### MDIO init
A small state machine sends the two 64-bit write frames above, with `MDC` = 60 MHz ÷ 32 ≈ 1.9 MHz, once after reset. It then raises a *configured* flag and goes quiet.

---

## 4. What stays the same
- The chip logic: `tx.ml`, `rx.ml`, `eth_core.ml`, `tt_top.ml`. Its Manchester encoder and receive PLL are still in the data path, just between the chip and the bridge instead of on the cable.
- The TinyTapeout GDS, the formal proofs and the UPduino build.
- `program.tcl`. It loads the FPGA's RAM only. **Nothing is written permanently**: power off or press PROG and the Arty returns to whatever is in its flash.

---

## 5. Files

| File | Role |
|---|---|
| `hardcaml/lib/mii_bridge.ml` | TX decoder + nibble FIFO + MII driver, and MII sampler + FIFO + Manchester encoder |
| `hardcaml/lib/mdio.ml` | Sends the two MDIO configuration writes |
| `hardcaml/lib/arty_mii.ml` | Board logic: demo host + chip + bridge + MDIO init + PHY reset timing + LEDs |
| `hardcaml/test/test_mii.ml` | Simulation tests for all of the above |
| `fpga/arty/top.v` | Clock (MMCM: 60 MHz + 25 MHz), 25 MHz out to the PHY via `ODDR`, MDIO pin buffer (`IOBUF`), power-on reset |
| `gen/eth10t_arty.v` | Generated from `arty_mii.ml` by `make verilog` |
| `fpga/arty/arty.xdc` | Pins: on-board Ethernet, clock, reset button, LEDs |
| `fpga/arty/build.tcl`, `program.tcl` | Vivado build and load (RAM only) |

`make arty` copies `top.v`, `eth10t_arty.v`, `arty.xdc`, `build.tcl`, `program.tcl` and this README to `D:\JaneStreet_Chip\eth10t`.

---

## 6. Pins (all on-board, from Digilent's Arty A7 master XDC)

Please cross-check these against your spec sheet.

| Signal | FPGA pin | | Signal | FPGA pin |
|---|---|---|---|---|
| `CLK100MHZ` | E3 | | `eth_tx_clk` | H16 |
| `ck_rst` (RESET button) | C2 | | `eth_tx_en` | H15 |
| `eth_ref_clk` (25 MHz out) | G18 | | `eth_txd[0..3]` | H14, J14, J13, H17 |
| `eth_rstn` | C16 | | `eth_rx_clk` | F15 |
| `eth_mdc` | F16 | | `eth_rx_dv` | G16 |
| `eth_mdio` | K13 | | `eth_rxd[0..3]` | D18, E17, E18, G17 |
| LD4..LD7 | H5, J5, T9, T10 | | | |

`eth_col`, `eth_crs` and `eth_rxerr` are not used. Our chip does its own carrier sense and collision detection.

## 7. LEDs and the check views

SW1/SW0 choose what LD4..LD7 show. **Both down is normal operation.**

| SW1 SW0 | View | LD4 | LD5 | LD6 | LD7 |
|---|---|---|---|---|---|
| 0 0 | Normal | Frame sent (blink ~1.1 s) | Good frame received | PHY configured | Running |
| 0 1 | MII | PHY's TX_CLK arriving | PHY's RX_CLK arriving | We drive TX_EN | PHY drives RX_DV |
| 1 0 | MDIO | PHY ID reads `0x2000` | Our 10 Mb/s setting reads back | PHY reports link up | PHY ever drove MDIO |

In the MII view, an LED stays lit for ~70 ms after each event, so a running clock shows as steady on. The MDIO view is refreshed continuously: the design keeps reading those registers.

**Reading the MDIO view.**
- LD7 off: the PHY never answers, so MDIO doesn't reach it (wrong PHY address or pins).
- LD7 on but LD4 off: MDIO works, but the device at address 1 isn't a DP83848.
- LD4 on but LD5 off: the PHY answers, but our setting didn't stick.

Switch pins (from Digilent's master XDC; please check against your sheet): SW0 = A8, SW1 = C11.

## 8. Steps
1. WSL: `make arty`
2. Vivado Tcl console:
   ```tcl
   cd D:/JaneStreet_Chip/eth10t
   source build.tcl
   source program.tcl
   ```
   Check that the printed worst setup slack is ≥ 0.
3. Plug a normal Ethernet cable from **the Arty's RJ45 port** to the PC.
4. In PowerShell:
   ```powershell
   Get-NetAdapter | Format-Table Name, Status, LinkSpeed
   ```
   `Ethernet` should show `Up` and `10 Mbps`. LD6 lights about 2 ms after programming, once the PHY is configured.
5. In Wireshark on that adapter, filter `eth.type == 0x88b5`. A frame arrives about every 1.1 s with:
   - source `02:48:43:31:30:54`
   - payload `Hello from Hardcaml 10BASE-T #n`

## 9. Troubleshooting

| Symptom | Check |
|---|---|
| `synth_design` part error | `set part` in `build.tcl`: A7-35T is `xc7a35ticsg324-1L`, A7-100T is `xc7a100tcsg324-1` |
| LD7 off | MMCM not locked, or the RESET button is held |
| LD6 never lights | The design is held in reset. MDIO starts ~2 ms after reset. |
| PC shows `Disconnected` | Cable fully in the **Arty's** RJ45 port; the adapter supports 10 Mb/s |
| PC links at 100 Mbps | The MDIO writes didn't take effect. Check that pins F16/K13 match your sheet and that the PHY address is 1. |
| LD4 blinks, but nothing in Wireshark | Capture on the right adapter (the "Ethernet" one, not Wi-Fi); filter `eth.type == 0x88b5` |

## 10. Verification results (simulation, `make test`)

`hardcaml/test/test_mii.ml` models the DP83848 at its MII pins:

| Test | Result |
|---|---|
| TX with the PHY's half-duplex echo modelled | Full frame sent, no collision. Before the echo fix, the frame died after 15 nibbles with COLLISION set, exactly as seen on the real board. |
| TX: chip → bridge → MII nibbles, sampled on a 2.5 MHz TX_CLK | 144 nibbles, identical to the reference frame (8 preamble/SFD + 60 data + 4 FCS bytes). Exactly 1 TX_EN burst: link pulses are correctly dropped. |
| RX: MII nibbles → bridge → chip, at −100 / 0 / +100 ppm | Bytes and CRC correct in all 6 cases, including when the PHY passes only the SFD and no preamble |
| End to end: chip A → MII → PHY pair (80 ppm apart) → MII → chip B | Frame intact, CRC OK |
| MDIO | 128 bits, bit exact: PHY 1 reg 4 = `0x0021`, then PHY 1 reg 0 = `0x1200` |
| Whole board logic (`arty_mii.ml`) | PHY released from reset, then configured, then the first demo frame on MII matches the reference |

The chip itself is unchanged. Its tests, formal proofs and cocotb results still pass. `yosys synth_xilinx` builds `top.v` + `eth10t_arty.v` with the expected primitives: MMCM, 2 × BUFG, ODDR, IOBUF, and LUT-RAM FIFOs.

## 11. Honest limits
- Vivado isn't installed here, so the Vivado build and its timing are checked on your side. The logic is tested in simulation, and the wrapper is checked with yosys.
- The PHY is modelled at its pins from the MII/MDIO standards. The real DP83848's behaviour, such as exactly how much preamble it passes on, is covered by testing both extremes.
- The pin locations come from Digilent's master XDC, so please confirm them against your sheet (§6).
- The cable-side analog work (Manchester on the actual wire, link pulses) is done by the DP83848 here, not by our chip. Our chip's Manchester encoder and receiver still run, but on the FPGA-internal link to the bridge. The full on-cable version is the TinyTapeout chip.

## 12. Hardware status (where this stopped)

**Observed on the board** (Windows adapter forced to 10 Mbps Half Duplex):
| Check | Result |
|---|---|
| Vivado build | OK, WNS +7 ns; `program.tcl` OK |
| LEDs, normal view | LD4 blinking (frames sent), LD6 on (MDIO writes sent), LD7 on (running), **LD5 off** (nothing received) |
| `Get-NetAdapter` | Link `Up`. **100 Mbps with the adapter on auto**, so our 10 Mb/s setting isn't taking effect. 10 Mbps when forced. |
| Wireshark / `pktmon` | **None** of our frames (filter `eth.src == 02:48:43:31:30:54` or `eth.type == 0x88b5`) |
| Adapter counters | 0 broadcast packets received, 0 errors |
| RJ45 activity LED | Blinks irregularly (consistent with the PC's own traffic) |

**Fixed along the way:**
- the `design` keyword in `top.v`;
- the PHY's half-duplex echo (it made our chip abort every frame as a collision; reproduced in simulation);
- RX sampling moved to before the clock edge.

**Unresolved.** The PHY links, but it doesn't act on anything the FPGA sends it, whether MDIO settings or transmit data, and nothing it receives reaches our chip. The fault is in the FPGA↔PHY interface or in an assumption about the PHY: pins, mode, address, or a behaviour our model lacks. The Ethernet logic itself passes every simulation.

**Next step (not yet done).** Read the check views in §7:
- SW0 up, then SW1 up, noting LD4–LD7 each time.
- They show directly whether the PHY's clocks arrive, whether TX_EN leaves the FPGA, and whether the PHY answers MDIO with its ID.
