# Port a model to TPU

Bring a PyTorch or JAX model up on Cloud TPU, then make it beat the GPU baseline. Size the job first with [Size a job before you ask for chips](./README.md#size-a-job-before-you-ask-for-chips) and [Fit matmuls to the MXU](./README.md#tpu-fit-matmuls-to-the-mxu).

## Start with TorchTPU

For PyTorch, start with TorchTPU. Google's [PyTorch on TPU](https://docs.cloud.google.com/tpu/docs/pytorch-on-tpu) page covers it, plus vLLM-TorchTPU and SGLang-TorchTPU for serving and TorchTitan for training, and the [TorchTPU docs](https://torchtpu.readthedocs.io/en/latest/) cover install and APIs. To run TorchTPU with Ray on GKE, start from Google's [fine-tuning](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/train-models-tpu-ray-torchtpu) and [serving](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/serve-llm-tpu-ray-torchtpu) tutorials.

To port a PyTorch model with a harness, try the [TPU agent suite](https://github.com/google-pytorch/tpu-agent-suite) (Preview, Claude Code and Antigravity).

For serving recipes that already run vLLM-TorchTPU on Ironwood and Trillium, see [Start from a recipe](../workloads/README.md#start-from-a-recipe).

## What worked on our ports, in order

1. Get it running before you make it fast. Expect the first number to lose to the GPU; that's normal for an untuned port.
2. Name the baseline you got. If you compared against a different GPU than planned, say so in every readout.
3. Sweep architecture choices before tuning flags. In vLLM's TPU backend, switching the MoE kernel backend moved throughput more than any command-line flag did.
4. When summary numbers stop helping, switch to profiles, which show where the time goes. tpu-inference ships [`tpu_profiling.py`](https://github.com/vllm-project/tpu-inference/blob/bec31b7cce132ed995daed8d39321b943d15be73/examples/tpu_profiling.py). [Profile with XProf](../monitoring/README.md#profile-with-xprof) shows how to read a profile.
5. Profile prefill and decode separately. They have different bottlenecks, and averaging hides both.
6. Treat correctness, quantization and upstreaming as part of the port. For correctness, run several dozen prompts at temperature 0 against the GPU implementation and check every prompt where the tokens differ.

## Write a Pallas kernel

For a custom Pallas kernel, try [MaxKernel](https://github.com/AI-Hypercomputer/accelerator-agents/tree/main/maxkernel) before you write one by hand. It's an open-source agent that turns a JAX, CUDA or PyTorch kernel into a Pallas kernel, then compiles, tests, tunes and profiles it on a real TPU. It runs as a [Claude Code plugin](https://github.com/AI-Hypercomputer/accelerator-agents/blob/main/maxkernel/claude-code/README.md), and the method is in [the paper](https://arxiv.org/abs/2609.04523).

## How TorchTPU works

- [TorchTPU is now open source](https://cloud.google.com/blog/topics/ai-infrastructure/torchtpu-is-now-open-source-run-native-pytorch-on-tpus), the launch post
- Deep dives on [vLLM and SGLang](https://developers.googleblog.com/announcing-new-vllm-and-sglang-inference-engines-on-tpu/) and [TorchTitan](https://developers.googleblog.com/integrating-torchtpu-into-torchtitan-and-optimizing-models-for-tpu/)
- The [TorchTPU paper](https://arxiv.org/abs/2610.24161)
