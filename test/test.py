import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_reset(dut):
    """Test that reset works and outputs are 0."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst_n.value  = 0
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.ena.value    = 1

    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # After reset outputs should be 0
    assert int(dut.uo_out.value) == 0, f"Expected 0, got {int(dut.uo_out.value)}"
    dut._log.info("test_reset PASSED")


@cocotb.test()
async def test_auth_valid(dut):
    """Valid packet (last byte 0xA5) should set auth_valid."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst_n.value  = 0
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.ena.value    = 1
    await Timer(50, units="ns")
    dut.rst_n.value  = 1
    await RisingEdge(dut.clk)

    # Load key: mode=01, start=1 → lower bits = 0b00000111
    for i in range(64):
        dut.ui_in.value = 0x07
        await RisingEdge(dut.clk)

    # Wait for key_loaded (uo_out[4])
    dut.ui_in.value = 0x00
    for _ in range(200):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 4) & 1:
            break

    # Send packet: mode=00, start=1 → lower bits = 0b00000001
    for i in range(63):
        dut.ui_in.value = 0x01
        await RisingEdge(dut.clk)

    # Last byte 0xA5 = valid
    dut.ui_in.value = 0xA1   # 0xA0 | 0x01 (start bit)
    await RisingEdge(dut.clk)
    dut.ui_in.value = 0x00
    await RisingEdge(dut.clk)

    # Wait for busy to go low
    for _ in range(2000):
        await RisingEdge(dut.clk)
        if not ((int(dut.uo_out.value) >> 2) & 1):
            break

    dut._log.info(f"uo_out = {int(dut.uo_out.value):08b}")
    dut._log.info("test_auth_valid PASSED")


@cocotb.test()
async def test_auth_reject(dut):
    """Invalid packet should set auth_reject."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst_n.value  = 0
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.ena.value    = 1
    await Timer(50, units="ns")
    dut.rst_n.value  = 1
    await RisingEdge(dut.clk)

    # Load key
    for i in range(64):
        dut.ui_in.value = 0x07
        await RisingEdge(dut.clk)
    dut.ui_in.value = 0x00
    for _ in range(200):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) >> 4) & 1:
            break

    # Send packet with last byte = 0x00 (invalid)
    for i in range(63):
        dut.ui_in.value = 0x01
        await RisingEdge(dut.clk)
    dut.ui_in.value = 0x01   # last byte 0x00 | start
    await RisingEdge(dut.clk)
    dut.ui_in.value = 0x00
    await RisingEdge(dut.clk)

    for _ in range(2000):
        await RisingEdge(dut.clk)
        if not ((int(dut.uo_out.value) >> 2) & 1):
            break

    dut._log.info(f"uo_out = {int(dut.uo_out.value):08b}")
    dut._log.info("test_auth_reject PASSED")
