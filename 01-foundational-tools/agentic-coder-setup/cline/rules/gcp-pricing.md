# GCP pricing lookups (gcp-pricing CLI)

A CLI named `gcp-pricing` is installed on PATH. Use it whenever you need a Google Cloud price, cost, rate, or $/hr for ANY product (VMs, GPUs, TPUs, BigQuery, storage, Spanner, Cloud Run, ...). The official pricing pages are JavaScript-rendered, so fetching the URL returns an empty shell — this tool scrapes the numbers embedded in the page.

Run it with your terminal/execute-command tool and read stdout:

    gcp-pricing <product|url> [--filter TEXT ...] [--json]

Examples:
    gcp-pricing accelerator --filter h200 --filter netherlands
    gcp-pricing tpu --filter Trillium
    gcp-pricing bigquery --filter slot
    gcp-pricing https://cloud.google.com/spanner/pricing

The tool does NO interpretation: it returns the page's own column headers and raw cell strings, verbatim — YOU read the table. A cell may be "-" (not offered in that region) or "$X / 1 hour". Every result prints a "Source (open to verify)" URL; share it so the user can eye-check on the page. `--filter` is a substring match over a row (repeat for AND). Known names: vms, accelerator, gpu, tpu, storage, lustre, parallelstore, bigquery, cloud-run, gke, spanner, cloud-sql, vertex-ai. Anything else: pass the pricing URL directly.
