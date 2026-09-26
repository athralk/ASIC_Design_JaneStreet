# SPDX-License-Identifier: Apache-2.0
"""Tile-level tests for TinyTapeout CI: RTL and gate-level netlist."""

import zlib

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

CLOCK_PS = 16_666  # 60 MHz (must be an even number of ps)
TX_READY, RX_VALID, RX_FRAME, LINK_UP = 0x10, 0x20, 0x40, 0x80
TX_BUSY, COLLISION, CRC_OK = 0x01, 0x04, 0x10


def expected_rx(payload):
    """What the receiver hands its host: data padded to 60 bytes, then the FCS."""
    data = bytes(payload) + bytes(max(0, 60 - len(payload)))
    return data + zlib.crc32(data).to_bytes(4, "little")


async def reset(dut):
    dut.ena.value = 1
    dut.a_ui_in.value = 0
    dut.b_ui_in.value = 0
    dut.a_tx_valid.value = 0
    dut.b_tx_valid.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1


async def send(dut, node, payload):
    """Host side of the TX pin protocol."""
    ui_in, tx_valid, uio_out = (
        getattr(dut, f"{node}_ui_in"),
        getattr(dut, f"{node}_tx_valid"),
        getattr(dut, f"{node}_uio_out"),
    )
    ui_in.value = payload[0]
    tx_valid.value = 1
    for i in range(len(payload)):
        while True:  # rising edge of tx_ready: byte i was taken
            await RisingEdge(dut.clk)
            prev = int(uio_out.value) & TX_READY
            await FallingEdge(dut.clk)
            if int(uio_out.value) & TX_READY and not prev:
                break
        if i + 1 < len(payload):
            ui_in.value = payload[i + 1]
    tx_valid.value = 0


async def receive(dut, node):
    """Host side of the RX pin protocol: returns (bytes, status)."""
    uo_out, uio_out = getattr(dut, f"{node}_uo_out"), getattr(dut, f"{node}_uio_out")
    data, prev = [], 0
    while True:
        await FallingEdge(dut.clk)
        u = int(uio_out.value)
        if u & RX_VALID and not prev & RX_VALID:
            data.append(int(uo_out.value))
        if prev & RX_FRAME and not u & RX_FRAME:
            return bytes(data), int(uo_out.value)
        prev = u


@cocotb.test()
async def test_pins(dut):
    cocotb.start_soon(Clock(dut.clk, CLOCK_PS, unit="ps").start())
    await reset(dut)
    await ClockCycles(dut.clk, 2)
    assert int(dut.a_uio_oe.value) == 0xF3
    assert int(dut.a_uio_out.value) & 0x03 == 0, "line idle after reset"


@cocotb.test()
async def test_frame_a_to_b(dut):
    cocotb.start_soon(Clock(dut.clk, CLOCK_PS, unit="ps").start())
    await reset(dut)
    payload = list(b"Hello from Hardcaml 10BASE-T")
    rx = cocotb.start_soon(receive(dut, "b"))
    await send(dut, "a", payload)
    data, status = await rx
    dut._log.info(f"B got {len(data)} bytes, status {status:#04x}")
    assert data == expected_rx(payload)
    assert status & CRC_OK
    assert status & LINK_UP


@cocotb.test()
async def test_frame_b_to_a_long(dut):
    cocotb.start_soon(Clock(dut.clk, CLOCK_PS, unit="ps").start())
    await reset(dut)
    payload = [(i * 37 + 11) & 0xFF for i in range(100)]
    rx = cocotb.start_soon(receive(dut, "a"))
    await send(dut, "b", payload)
    data, status = await rx
    assert data == expected_rx(payload)
    assert status & CRC_OK


@cocotb.test()
async def test_collision(dut):
    cocotb.start_soon(Clock(dut.clk, CLOCK_PS, unit="ps").start())
    await reset(dut)
    # Both sides start together: each sees carrier while transmitting and jams.
    dut.a_ui_in.value = 0x55
    dut.b_ui_in.value = 0xAA
    dut.a_tx_valid.value = 1
    dut.b_tx_valid.value = 1
    await ClockCycles(dut.clk, 3000)
    dut.a_tx_valid.value = 0
    dut.b_tx_valid.value = 0
    await ClockCycles(dut.clk, 200)
    for node in ("a", "b"):
        uio = int(getattr(dut, f"{node}_uio_out").value)
        status = int(getattr(dut, f"{node}_uo_out").value)
        assert not uio & RX_FRAME
        assert status & COLLISION, f"{node} should report a collision"
        assert not status & TX_BUSY
