## How it works

A half-duplex 10BASE-T Ethernet transceiver written in [Hardcaml](https://github.com/janestreet/hardcaml).
It runs from a single 60 MHz clock (3 clocks per 50 ns Manchester half-bit).

**Transmit.** The host streams payload bytes. The chip adds the 7-byte preamble and the SFD,
pads the frame to 60 bytes, appends the CRC-32 FCS, and ends it with the 250 ns TP_IDL.
Every bit is Manchester-encoded onto TD+/TD-. When the line is idle it sends a 100 ns
normal link pulse (NLP) every 16 ms. It defers to traffic on the line plus a 9.6 µs
inter-packet gap, jams on a collision, and cuts off a host that transmits for more than
about 34 ms (jabber).

**Receive.** RD is sampled on both clock edges, giving 8.3 ns resolution. A digital PLL
tracks the mid-bit transitions with a loop-filtered bang-bang correction, and decodes
each bit from the direction of its mid-bit edge. It finds the SFD, assembles the bytes,
and checks the CRC after every byte. NLPs and the link-integrity timer drive LINK_UP.
In simulation it receives error-free with ±13.5 ns of random edge jitter (the 802.3
Clause 14 limit) and ±100 ppm clock offset.

TX and RX share one CRC engine, since 10BASE-T is half duplex.

### Host protocol

- **TX:** put byte 0 on `ui_in`, then raise `TX_VALID`. Each rising edge of `TX_READY` means
  the byte on `ui_in` was taken, so put the next one there. After the last byte's
  `TX_READY`, drop `TX_VALID` within 800 ns. Keep `TX_VALID` low for at least 4 clocks
  between frames. The status bits report `TX_BUSY`, `COLLISION` and `JABBER`.
- **RX:** while `RX_FRAME` is high, each rising edge of `RX_VALID` means a new byte is on
  `uo_out`. This includes the 4 FCS bytes. When `RX_FRAME` falls, `uo_out` shows the
  status byte, which includes `CRC_OK`.
- Hold `rst_n` low for at least 4 clocks.

## How to test

Clock the design at 60 MHz. The RP2040 on the demo board can provide it (120 MHz / 2).
A PIO program can drive the byte interface. Connect TD+/TD- to the TX pair of an RJ45
MagJack through about 100 Ω series resistors. Feed RD from a comparator (for example a
TLV3501) across the RX pair, biased so that an idle line reads 0.

Plug it into a PC's Ethernet port. The PC should report a 10 Mb/s half-duplex link,
from parallel detection of our NLPs, and Wireshark shows the transmitted frames.

## External hardware

RJ45 jack with integrated magnetics, two resistors for TX, and a fast comparator for RX.
