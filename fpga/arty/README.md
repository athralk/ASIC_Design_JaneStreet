# Ethernet on the Arty A7's own RJ45 port

> **Status: working on hardware.** The PC captures our frames in Wireshark (`Hello from Hardcaml 10BASE-T #n`), the FPGA receives the PC's frames (LD5), and the link is 10 Mbps. The first version never worked; §9 explains why and what changed.

The cable goes into **the Arty's built-in RJ45 port**. There is no extra hardware.

---

## 1. The idea in one picture

```
 PC ──cable──► DP83848 PHY ──MII──► FPGA:  MII MAC  (TX on TX_CLK, RX on RX_CLK)
  (on the Arty board)      ◄─MDIO─         MDIO     (set 10 Mb/s, read the link status)
```

The FPGA never touches the cable signal. The **PHY chip** (TI DP83848) does all the analog and line-coding work. It exchanges 4-bit words (*nibbles*) with the FPGA over **MII**. The FPGA only has to be a **MAC**: build frames going out, and check frames coming in.

---

## 2. Background: MAC, PHY, MII, MDIO

| Part | Job |
|---|---|
| **MAC** | Frames: preamble, addresses, padding, CRC |
| **PHY** | Bits ↔ cable signal: Manchester (10 Mb/s) or 4B5B/MLT-3 (100 Mb/s), link pulses, clock recovery, auto-negotiation |

**MII signals** (the same wires at both speeds):

| Signal | Direction | 10 Mb/s | 100 Mb/s | Meaning |
|---|---|---|---|---|
| `TX_CLK` | PHY → FPGA | 2.5 MHz | 25 MHz | The FPGA changes `TXD`/`TX_EN` on its rising edge; the PHY samples on the next one |
| `TXD[3:0]`, `TX_EN` | FPGA → PHY | | | One nibble per clock; `TXD[0]` goes on the wire first |
| `RX_CLK` | PHY → FPGA | 2.5 MHz | 25 MHz | Recovered from the incoming signal |
| `RXD[3:0]`, `RX_DV` | PHY → FPGA | | | The received nibble, valid at the rising edge of `RX_CLK` |
| `CRS` | PHY → FPGA | | | Carrier: someone is talking on the cable |

**The key rule.** `TX_CLK` and `RX_CLK` **are the clocks** for the MAC logic: every register that touches `TXD` runs on `TX_CLK`, and every register that touches `RXD` runs on `RX_CLK`. Because MII carries 4 bits per clock at both speeds, the **same logic works at 10 and 100 Mb/s**. Only the clock frequency changes.

**MDIO** is a slow two-wire management bus: `MDC` is the clock and `MDIO` is the data. The FPGA uses it to read and write the PHY's registers at PHY address 1.

---

## 3. What the FPGA does

### Transmit (`hardcaml/lib/mii_mac.ml`, `Tx`, clocked by `TX_CLK`)
Once a second it sends one frame, nibble by nibble:

| Part | Nibbles | Content |
|---|---|---|
| Preamble + SFD | 16 | fifteen `0x5`, then `0xD` |
| Data | 120 | broadcast destination, source `02:48:43:31:30:54`, type `0x88B5`, `"Hello from Hardcaml 10BASE-T #"`, a sequence byte, zero padding up to 60 bytes. Each byte goes out low nibble first. |
| FCS | 8 | CRC-32 of the data, complemented, LSB first |
| Gap | ≥ 32 | `TX_EN` low (at least the 96-bit inter-frame gap) |

It waits while `CRS` is high, so it never starts talking over the PC in half duplex.

### Receive (`Rx`, clocked by `RX_CLK`)
1. When `RX_DV` rises, skip `0x5` preamble nibbles until the `0xD` of the SFD.
2. Run every following nibble through the CRC-32.
3. When `RX_DV` falls: the frame is **good** if the CRC register holds the residue `0xDEBB20E3`, the frame is a whole number of bytes, and it is at least 64 bytes long.
4. Compare the source address with our own. In 10 Mb/s half duplex the DP83848 copies everything we send back onto `RXD`, so a frame from our own address is our **echo**, not the PC's.

### Control (`hardcaml/lib/arty_mii.ml`, 25 MHz system clock)
- Holds the PHY in reset for 1.3 ms, then releases it.
- MDIO writes: register 4 = `0x0061` (advertise 10 Mb/s only, half and full duplex), then register 0 = `0x1200` (restart auto-negotiation). With Windows on auto, the link then comes up at **10 Mbps full duplex**.
- MDIO reads, repeated forever: register 2 (PHY ID, should be `0x2000`) and register 0x10 (PHYSTS: link, speed and duplex as the PHY sees them).
- Triggers a frame every ~1.3 s, and drives the LEDs.

Clock-domain crossings (system ↔ TX ↔ RX) use toggle signals through 2-flop synchronisers.

---

## 4. Pins (on-board, from Digilent's Arty A7 master XDC)

| Signal | Pin | | Signal | Pin |
|---|---|---|---|---|
| `CLK100MHZ` | E3 | | `eth_tx_clk` | H16 |
| `ck_rst` (RESET button) | C2 | | `eth_tx_en` | H15 |
| `eth_ref_clk` (25 MHz out) | G18 | | `eth_txd[0..3]` | H14, J14, J13, H17 |
| `eth_rstn` | C16 | | `eth_rx_clk` | F15 |
| `eth_mdc` | F16 | | `eth_rx_dv` | G16 |
| `eth_mdio` | K13 | | `eth_rxd[0..3]` | D18, E17, E18, G17 |
| `eth_crs` | G14 | | SW0 | A8 |
| LD4..LD7 | H5, J5, T9, T10 | | | |

## 5. LEDs

| SW0 | LD4 | LD5 | LD6 | LD7 |
|---|---|---|---|---|
| down (normal) | frame sent (blinks ~1.3 s) | good frame received from the PC | link up (read over MDIO) | link is 10 Mb/s |
| up (check) | MDIO works (PHY ID reads `0x2000`) | PHY is receiving anything (`RX_DV`) | our own frame echoed back (10 Mb/s half duplex only) | full duplex |

## 6. Steps
1. WSL: `make arty`
2. Vivado Tcl console:
   ```tcl
   cd D:/JaneStreet_Chip/eth10t
   source build.tcl
   source program.tcl
   ```
   Worst setup slack must be ≥ 0. The load is RAM only: power-off or PROG restores the flash design.
3. Put the Windows Ethernet adapter back on **Auto Negotiation**, then plug the cable into the Arty's RJ45 port.
4. PowerShell: `Get-NetAdapter | Format-Table Name, Status, LinkSpeed` should show `Up`, `10 Mbps`.
5. Wireshark on that adapter, filter `eth.type == 0x88b5`: one frame about every 1.3 s.

## 7. What has been checked

| Check | Result |
|---|---|
| TX nibbles vs. an independent software model of the frame (`reference.ml`), including CRC | 144 nibbles, identical |
| RX: a PC frame / only the SFD, no preamble / one bit flipped / our own frame echoed | good (LD5) / good / rejected / counted as echo only |
| MDIO against a PHY model | writes reg 4 = `0x0061`, reg 0 = `0x1200`; PHY ID and PHYSTS read back to the LEDs |
| `yosys synth_xilinx` of `top.v` + `eth10t_arty.v` | MMCM, 3 BUFG (system, TX_CLK, RX_CLK), ODDR, IOBUF, 11 inputs, 12 outputs, ~340 LUTs |

**On the board** (Vivado 2025.2, Windows PC, adapter on auto):

| Check | Result |
|---|---|
| Vivado timing | All constraints met: WNS +6.845 ns, WHS +0.128 ns (MII clocks constrained at 25 MHz, the worst case) |
| Vivado utilisation | 336 LUTs, 311 flip-flops |
| `Get-NetAdapter` | `Up`, `10 Mbps`: our MDIO advertisement took effect |
| Wireshark | `02:48:43:31:30:54 → Broadcast, 0x88b5, 60 bytes`, payload `Hello from Hardcaml 10BASE-T #`, sequence byte incrementing. (The NIC strips the 4-byte FCS and drops frames with a bad CRC, so seeing the frame proves the CRC.) |
| LEDs, SW0 down | LD4 blinks per frame, LD5 blinks on the PC's broadcasts, LD6 on (link), LD7 on (10 Mb/s) |

The first v2 attempt showed only LD4: the cable wasn't fully pushed into the laptop. Check both ends first.

## 8. Troubleshooting (read the LEDs first)

| What you see | Meaning | Do |
|---|---|---|
| SW0 up, LD4 off | MDIO gets no PHY ID back: wrong pins or PHY address | Tell me; nothing else depends on MDIO |
| LD6 off, but the RJ45 link light is on | Same as above (link is read over MDIO) | As above |
| LD7 off while linked | The link is 100 Mb/s: our 10 Mb/s advertisement didn't stick | Still works; set Windows to "10 Mbps Full Duplex" if you want 10 Mb/s |
| LD4 blinks, nothing in Wireshark | Check you capture the Ethernet adapter, not Wi-Fi; try without a filter | Note what the RJ45 lights do |
| LD5 never blinks | Windows sends broadcasts (ARP, mDNS, …) every few seconds once linked; if LD5 stays dark, RX is broken | SW0 up: does LD5 (RX_DV) blink? |
| Worst setup slack < 0 | MII timing not met | Send me `out/timing.rpt` |

## 9. Why version 1 failed, and what changed

| v1 (failed on the board) | Problem | v2 |
|---|---|---|
| Ran everything on the FPGA's own 60 MHz clock and *sampled* `TX_CLK`/`RX_CLK` as data | Only works if the clocks are 2.5 MHz. With Windows on auto the link came up at **100 Mb/s**, where these clocks are 25 MHz: too fast to sample at 60 MHz. Every 100 Mb/s test was bound to fail, and I should have caught it at design time. | Logic is clocked **by** `TX_CLK`/`RX_CLK`, as MII intends, so it works at either speed |
| Depended on MDIO forcing 10 Mb/s, with no way to see whether it worked | The PC-on-auto link came up at 100 Mb/s, so the writes did not take effect, and nothing showed it | Link speed and duplex are read back and shown on LD6/LD7; the MAC works even if the write fails |
| Converted nibbles → Manchester → the chip's DPLL receiver, and back again for TX | Three conversions built on my model of the PHY, none visible on the board | Direct nibble MAC, no conversions |
| Ignored `CRS` | Could start talking over the PC in half duplex | Waits while `CRS` is high |
