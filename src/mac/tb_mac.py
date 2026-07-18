import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def mac_pipeline_test(dut):
    """Testbench untuk MAC Engine (Q15 format)"""

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 1
    dut.valid.value = 0
    dut.clear.value = 0
    dut.x.value = 0
    dut.c.value = 0

    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut._log.info("Reset selesai. Memulai injeksi data Q15...")

    # x = 0.5 (Q15: 16384), c = 0.5 (Q15: 16384), result = 0.25 (Q15: 8192)
    dut.valid.value = 1
    dut.clear.value = 1
    dut.x.value = 16384
    dut.c.value = 16384
    await RisingEdge(dut.clk)

    # x = 0.5 (Q15: 16384), c = 0.25 (Q15: 8192), result = 0.125 (Q15: 4096)
    # 0.25 + 0.125 = 0.375 (Q15: 12288)
    dut.clear.value = 0
    dut.x.value = 16384
    dut.c.value = 8192
    await RisingEdge(dut.clk)

    dut.valid.value = 0
    dut.x.value = 0
    dut.c.value = 0

    for i in range(3):
        await RisingEdge(dut.clk)
        dut._log.info(f"Cycle {i+1} Output (y) = {dut.y.value.signed_integer}, Done = {dut.done.value}")


    final_result = dut.y.value.signed_integer
    
    dut._log.info(f"Hasil Akhir Q15 (y) = {final_result}")
    
    assert final_result == 12288, f"Error: Ekspektasi 12288, tapi mendapatkan {final_result}"
    dut._log.info("Simulasi MAC Engine Sukses!")