![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tiny Tapeout Verilog Project Template

- [Read the documentation for project](docs/info.md)

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Set up your Verilog project

1. Add your Verilog files to the `src` folder.
2. Edit the [info.yaml](info.yaml) and update information about your project, paying special attention to the `source_files` and `top_module` properties. If you are upgrading an existing Tiny Tapeout project, check out our [online info.yaml migration tool](https://tinytapeout.github.io/tt-yaml-upgrade-tool/).
3. Edit [docs/info.md](docs/info.md) and add a description of your project.
4. Adapt the testbench to your design. See [test/README.md](test/README.md) for more information.

The GitHub action will automatically build the ASIC files using [LibreLane](https://www.zerotoasiccourse.com/terminology/librelane/).

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
  - Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)
 
  - # Fast Authentication Accelerator
### Tiny Tapeout — VLSI Training Project

> **Low-Latency Digital Signature Verification for V2X Communication**
> ECDSA hardware accelerator — verifies automotive V2X messages in under 1 ms.

## Overview

Every V2X message must be digitally verified before acting on it.
At highway speeds this must happen in **< 1 ms** — impossible in software.
This accelerator offloads ECDSA signature verification into dedicated hardware.

## Pin Description

| Pin | Name | Description |
|---|---|---|
| `ui_in[7:0]` | `data_in` | Input bytes (packet / key stream) |
| `ui_in[0]` | `start` | Pulse HIGH to begin operation |
| `ui_in[1]` | `soft_rst` | Soft reset |
| `ui_in[3:2]` | `mode` | `00`=verify, `01`=load_key |
| `uo_out[0]` | `auth_valid` | Signature accepted |
| `uo_out[1]` | `auth_reject` | Signature rejected |
| `uo_out[2]` | `busy` | Core is processing |
| `uo_out[3]` | `ecc_done` | ECC step complete pulse |
| `uo_out[4]` | `key_loaded` | Public key is loaded |
| `uo_out[5]` | `packet_ready` | Full packet received |
| `uio_*` | — | Unused (tied off) |

## Architecture

| Module | File | Description |
|---|---|---|
| Top-level | `src/tt_um_fast_auth.v` | TT wrapper, I/O |
| Auth Coprocessor | `src/auth_coprocessor.v` | FSM, protocol parsing |
| Key Manager | `src/key_manager.v` | Key cache |
| Modular Inverse | `src/mod_inverse.v` | s⁻¹ mod n |
| ECC Blocks | `src/ecc_blocks.v` | Scalar mult, Point mult, Comparator |

## Simulate

```bash
pip install cocotb
sudo apt install iverilog
cd test/
make
```

## Design Flow

1. RTL Coding → 2. Simulation → 3. Synthesis (Yosys) → 4. STA (OpenSTA) → 5. GDS

## Standards

IEEE 1609.2 · FIPS 186-4 · NIST P-256 · AEC-Q100

## License
Apache 2.0
