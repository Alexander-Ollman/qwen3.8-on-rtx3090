# The AI Frontier: No Datacenter Required

**Running Qwen3.8-27B optimally on an RTX 3090.** Five days of measuring **Qwen3.8-27B** on consumer NVIDIA hardware (2× RTX 3090, 24 GB each, Ampere, no NVLink) — from the out-of-the-box install to a configuration **7.7× faster**, and the silent failure modes that produced confident wrong numbers along the way.

**Read it:** https://alexander-ollman.github.io/qwen3.8-on-rtx3090/

## October update: the full 262K window on one card, and Unleashed-27B

Through llama.cpp (b10902, one RTX 3090, MTP draft, one slot), **Unsloth's UD-Q4_K_M with q4_0 KV holds the model's full 262,144-token window at 22.4 GiB**. It is slow at depth, and q4_0 KV quality at depth is not measured yet, so **fp8 KV at 150K on patched vLLM stays the recommendation up to 150K**.

[Unleashed-27B](https://huggingface.co/outsourc-e/Qwen3.8-27B-Unleashed-GGUF) is JonathanColetti's abliterated (uncensored) base model in Unsloth's quant recipe, with no training of its own:

| One card, llama.cpp | Stock Unsloth UD-Q4_K_M | Unleashed UD-Q4_K_M |
|---|---|---|
| Max context, q8_0 / q4_0 KV | 196,608 / 262,144 | 196,608 / 262,144 |
| Decode, short prompt (q8_0 / q4_0 KV) | 53 / 53 tok/s | 55 / 50 tok/s |
| At 261K (q4_0): prefill / decode / first token | 459 / 19.0 tok/s / 9.6 min | 455 / 19.5 tok/s / 9.7 min |
| Mean KL divergence vs own family's Q8_0 | 0.063 | 0.071 |
| LiveCodeBench v6 (60 problems, thinking on) | 63.3% (= bartowski base) | rerun still running |

The uncensoring alone (Unleashed Q8_0 vs stock Q8_0) is KLD **0.032**, about half what 4-bit quantization costs. No speed or fit advantage; the only reason to serve it is refusals.

## September update: the best way to use it with thinking on

[Swift-Qwen3.8-27B](https://huggingface.co/ukisai/Swift-Qwen3.8-27B) is a fine-tune that claims ~50% fewer thinking tokens for under a point of accuracy. Tested against the base model with quantization held identical (bartowski Q4_K_M of both, llama.cpp, thinking on, 32K cap):

| Same problems, thinking on | Base | Swift |
|---|---|---|
| LiveCodeBench v6 (60 problems) pass@1 | 63.3% | 71.7% |
| — median output tokens | 14,190 | **7,035 (−50%)** |
| — answers cut off at the cap | 19 | 14 |
| Aider polyglot (36 exercises) solved | 69.4% | 66.7% |
| — median reasoning tokens per request | 4,678 | **1,994 (−57%)** |
| — time spent (summed per exercise) | 9.6 h | **5.5 h** |

The token claim holds. The accuracy gain is an artefact of the output cap: no truncated answer passed, and on problems neither model truncated the score is identical (37 vs 37). **Serve the base model through patched vLLM when thinking is off; run Swift when it is on.** Small samples, one seed: pass rates are ±12 points.

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
sudo nvidia-smi -pl 250   # every figure here is at 250 W; GPU 0 has hit Xid 79 three times, cause open
sudo nvidia-smi -pm 1
```

## Honest limits

One model, one machine, one architecture family, mostly at 4-bit. The fastest configuration is a third-party fork ([syv-ai/qwen38-27b-rtx3090](https://github.com/syv-ai/qwen38-27b-rtx3090)) whose optimizations are checkpoint-specific. **None of these figures are comparable to published leaderboard numbers** — different quantization, harness versions, reasoning settings and serving stacks all move them independently.

Predecessor: [qwen3.6-on-rtx3090](https://github.com/Alexander-Ollman/qwen3.6-on-rtx3090)

## License

MIT
