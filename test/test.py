# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

CLK_PERIOD_NS = 10  # 100 MHz clock

# ----------------------------------------------------------------
# Helper: Apply reset
# ----------------------------------------------------------------
async def reset_dut(dut):
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0
    await Timer(5 * CLK_PERIOD_NS, units="ns")
    dut.rst_n.value  = 1
    await RisingEdge(dut.clk)
    dut._log.info("Reset done")

# ----------------------------------------------------------------
# Helper: Load 64-byte public key
# mode=01, start=1 → ui_in lower nibble = 0b0111 = 0x07
# ----------------------------------------------------------------
async def load_key(dut):
    dut._log.info("Loading public key...")
    for i in range(64):
        # lower 4 bits: start=1, soft_rst=0, mode=01
        # upper 4 bits: dummy key data (i & 0xF shifted up)
        dut.ui_in.value = 0x07 | ((i & 0x0F) << 4)
        await RisingEdge(dut.clk)

    # Wait for key_loaded = uo_out[4]
    for _ in range(300):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 4) & 1:
            dut._log.info("Key loaded successfully")
            break

    dut.ui_in.value = 0x00  # deassert start
    await RisingEdge(dut.clk)

# ----------------------------------------------------------------
# Helper: Send packet and return result
# Last byte of packet decides outcome:
#   0xA5 → auth_valid
#   anything else → auth_reject
# ----------------------------------------------------------------
async def send_packet(dut, last_byte=0xA5):
    dut._log.info(f"Sending packet (last_byte=0x{last_byte:02X})...")

    # Send 63 dummy bytes  — mode=00, start=1 → lower nibble = 0x01
    for i in range(63):
        dut.ui_in.value = 0x01 | ((i & 0x0F) << 4)
        await RisingEdge(dut.clk)

    # Send final byte (determines pass/fail)
    dut.ui_in.value = (last_byte & 0xF0) | 0x01
    await RisingEdge(dut.clk)

    # Deassert start
    dut.ui_in.value = 0x00
    await RisingEdge(dut.clk)

    # Wait for busy to go LOW (max 2000 cycles)
    for _ in range(2000):
        await RisingEdge(dut.clk)
        busy = (int(dut.uo_out.value) >> 2) & 1
        if not busy:
            break

    auth_valid  = (int(dut.uo_out.value) >> 0) & 1
    auth_reject = (int(dut.uo_out.value) >> 1) & 1
    return auth_valid, auth_reject


# ================================================================
# TEST 1 — Valid signature should be accepted
# ================================================================
@cocotb.test()
async def test_auth_valid(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)
    await load_key(dut)

    valid, reject = await send_packet(dut, last_byte=0xA5)

    assert valid  == 1, f"FAIL: auth_valid should be 1, got {valid}"
    assert reject == 0, f"FAIL: auth_reject should be 0, got {reject}"
    dut._log.info("TEST 1 PASSED — valid signature accepted")


# ================================================================
# TEST 2 — Invalid signature should be rejected
# ================================================================
@cocotb.test()
async def test_auth_reject(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)
    await load_key(dut)

    valid, reject = await send_packet(dut, last_byte=0x00)

    assert valid  == 0, f"FAIL: auth_valid should be 0, got {valid}"
    assert reject == 1, f"FAIL: auth_reject should be 1, got {reject}"
    dut._log.info("TEST 2 PASSED — invalid signature rejected")


# ================================================================
# TEST 3 — busy should assert during processing
# ================================================================
@cocotb.test()
async def test_busy(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)
    await load_key(dut)

    # Start sending packet
    dut.ui_in.value = 0x01   # start=1, mode=00
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    busy = (int(dut.uo_out.value) >> 2) & 1
    assert busy == 1, f"FAIL: busy should be 1 during processing, got {busy}"
    dut._log.info("TEST 3 PASSED — busy asserted correctly")


# ================================================================
# TEST 4 — Reset should clear outputs
# ================================================================
@cocotb.test()
async def test_reset_clears_outputs(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())

    # First complete a valid auth
    await reset_dut(dut)
    await load_key(dut)
    await send_packet(dut, last_byte=0xA5)

    # Now apply reset again
    dut.rst_n.value = 0
    await Timer(3 * CLK_PERIOD_NS, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    out = int(dut.uo_out.value)
    assert (out & 0x07) == 0, f"FAIL: outputs should clear after reset, got {out:#010b}"
    dut._log.info("TEST 4 PASSED — reset clears all outputs")


# ================================================================
# TEST 5 — key_loaded output check
# ================================================================
@cocotb.test()
async def test_key_loaded(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    await reset_dut(dut)

    # Before loading key, key_loaded should be 0
    key_loaded = (int(dut.uo_out.value) >> 4) & 1
    assert key_loaded == 0, f"FAIL: key_loaded should be 0 before loading, got {key_loaded}"

    await load_key(dut)

    key_loaded = (int(dut.uo_out.value) >> 4) & 1
    assert key_loaded == 1, f"FAIL: key_loaded should be 1 after loading, got {key_loaded}"
    dut._log.info("TEST 5 PASSED — key_loaded signal works correctly")
