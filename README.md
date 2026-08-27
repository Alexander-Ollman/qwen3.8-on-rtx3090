# The AI Frontier: No Datacenter Required

**Running Qwen3.8-27B optimally on an RTX 3090.** Five days of measuring **Qwen3.8-27B** on consumer NVIDIA hardware (2× RTX 3090, 24 GB each, Ampere, no NVLink) — from the out-of-the-box install to a configuration **7.7× faster**, and the silent failure modes that produced confident wrong numbers along the way.

**Read it:** https://alexander-ollman.github.io/qwen3.8-on-rtx3090/

## Headline numbers (single RTX 3090, 4-bit, 1K-token prompt)

| Configuration | Decode tok/s |
|---|---|
| llama.cpp, out of the box | 27.6 |
| llama.cpp, tuned (FA + q8_0 KV + MTP) | 42.6 |
| Stock vLLM + MTP k=4 | 85.6 |
| Patched vLLM + MTP k=4 | 167.8 |
| **Patched vLLM + DFlash2 k=7** | **212.1** |

Mean of 5, spreads 0.1–2%. Two replicas behind a load balancer: **905 tok/s** aggregate at 16 concurrent. One card in batch mode: **960 tok/s** at 64 concurrent. Max context on one card: **192K** tokens (KVarN 4/2-bit KV).

Correctness (Aider polyglot, 225 exercises): **12.5%** solved cold, **48.7%** after test feedback.

## What's in this repo

| Path | Purpose |
|---|---|
| `index.html` | The story — how it started, how it ended, what went wrong |
| `results.html` | Every number and graph, with provenance on each |
| `method.html` | How it was measured; the six silent failure modes; the fairness contract |
| `setup.html` | Configs and commands to reproduce it |
| `log.html` | The unedited 20-section measurement log, corrections included |
| `configs/` | Verified deployment configs (compose, nginx, launch scripts) |

## Four things that lied to us

1. **Reasoning enabled by default** — with a server-side reasoning parser, the symptom is *empty content with HTTP 200*. Hit us 5 times across 4 harnesses.
2. **The second GPU is not idle** — running two benchmarks on two cards cost 39% accuracy. Benchmark sequentially.
3. **Comparing across prompt lengths** — speculative acceptance rises with context, so speed does too. We "found" a 20% error that didn't exist.
4. **Generated code hangs harnesses** — a `node` process spun 68 minutes at 99.9% CPU. Impose your own timeout.

## Before anything else

```bash
sudo nvidia-smi -pl 250   # 12V brownout took a card off the PCIe bus (Xid 79)
sudo nvidia-smi -pm 1
```

## Honest limits

One model, one machine, one architecture family, mostly at 4-bit. The fastest configuration is a third-party fork ([syv-ai/qwen38-27b-rtx3090](https://github.com/syv-ai/qwen38-27b-rtx3090)) whose optimizations are checkpoint-specific. **None of these figures are comparable to published leaderboard numbers** — different quantization, harness versions, reasoning settings and serving stacks all move them independently.

Predecessor: [qwen3.6-on-rtx3090](https://github.com/Alexander-Ollman/qwen3.6-on-rtx3090)

## License

MIT
