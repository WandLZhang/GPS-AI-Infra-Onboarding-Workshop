# Examples

Working builds to copy: recipes, full projects from a research landing zone down to a single demo, and capacity scripts.

## Start from a recipe

Copy a working recipe before you write anything new:

- [AI-Hypercomputer/tpu-recipes](https://github.com/AI-Hypercomputer/tpu-recipes): training and inference recipes for TPUs, including vLLM-TorchTPU serving on [Ironwood](https://github.com/AI-Hypercomputer/tpu-recipes/tree/main/inference/ironwood/vLLM/vLLM-TorchTPU) and [Trillium](https://github.com/AI-Hypercomputer/tpu-recipes/tree/main/inference/trillium/vLLM/vLLM-TorchTPU/Gemma4-26B).
- [AI-Hypercomputer/gpu-recipes](https://github.com/AI-Hypercomputer/gpu-recipes): the same for GPUs.
- [GoogleCloudPlatform/accelerated-platforms](https://github.com/GoogleCloudPlatform/accelerated-platforms): GKE reference architectures for inference and training.
- [MaxText](https://maxtext.readthedocs.io/en/latest/): LLM training in JAX on TPUs and GPUs.

To bring your own model up on TPU, see [Benchmark and port a model to TPU](../2-choose-hardware/benchmark-and-port-to-tpu.md).

## Full projects

From the organization down to a single demo:

| I want to | Repo |
|---|---|
| Build a landing zone for a research organization | [fast-science L0](https://github.com/WandLZhang/fast-science-0-stellar-engine) |
| Give each researcher a project on that landing zone | [fast-science-1-researcher-lab](https://github.com/WandLZhang/fast-science-1-researcher-lab) |
| Deploy a researcher's workload into that project | [fast-science-2-workload-catalog](https://github.com/WandLZhang/fast-science-2-workload-catalog) |
| Run one Slurm cluster across regions, with DWS and Spot partitions | [slurm-multi-region-gpu-public](https://github.com/WandLZhang/slurm-multi-region-gpu-public) |
| Let a class share TPUs through a queue | [shared-tpu-notebooks](https://github.com/WandLZhang/shared-tpu-notebooks), set up as in [classroom](../5-run/classroom/) |
| Burst protein folding across GPU and TPU Slurm partitions | [ai-infra-demo-proteins](https://github.com/WandLZhang/ai-infra-demo-proteins) |
| Run a campus demo from a talk track | [ai-infra-demo-proteins-template](https://github.com/WandLZhang/ai-infra-demo-proteins-template) |
| Serve and inspect LLMs on TPU | [tpu-mech-interp](https://github.com/WandLZhang/tpu-mech-interp) |

## Spray requests across zones and poll for capacity

These scripts live in [slurm-multi-region-gpu-public](https://github.com/WandLZhang/slurm-multi-region-gpu-public):

- [spot-spray](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/spot-spray.sh)
- [flex-spray](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/flex-spray.sh)
- [flex-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/flex-poll.sh)
- [calendar-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/calendar-poll.sh)
- [spot-obtainability-poll](https://github.com/WandLZhang/slurm-multi-region-gpu-public/blob/main/scripts/spot-obtainability-poll.sh)

Which capacity option to spray for is in [get capacity](../3-get-capacity/).
