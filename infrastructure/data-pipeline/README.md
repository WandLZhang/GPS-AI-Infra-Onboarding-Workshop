# Data Pipeline & Preparation for AI Workloads

> Where BigQuery and data preparation services fit in the AI/ML lifecycle — upstream of the [storage I/O layer](../storage/) that feeds GPUs and TPUs.

---

## 📋 Table of Contents

1. [Where BigQuery Fits](#1-where-bigquery-fits)
2. [BigQuery Capabilities for AI/ML](#2-bigquery-capabilities-for-aiml)
3. [Common Data Pipeline Patterns](#3-common-data-pipeline-patterns)
4. [BigQuery DataFrames (bigframes)](#4-bigquery-dataframes-bigframes)
5. [Export Formats & Tooling](#5-export-formats--tooling)
6. [Relationship to Storage I/O Layer](#6-relationship-to-storage-io-layer)

---

## 1. Where BigQuery Fits

BigQuery operates **upstream** of the accelerator storage layer. It prepares, transforms, and exports data that ultimately lands in GCS — where [GCSFuse, Rapid Cache, and Rapid Bucket](../storage/) deliver it to GPUs/TPUs at high throughput.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AI/ML DATA LIFECYCLE                                │
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌───────────┐ │
│  │  DATA SOURCES │    │  PREPARATION │    │  STORAGE I/O │    │ COMPUTE   │ │
│  │              │    │              │    │              │    │           │ │
│  │  • BigQuery  │───▶│  • BigQuery  │───▶│  • GCS       │───▶│  • GPU    │ │
│  │  • Databases │    │    SQL/ML    │    │  • GCSFuse   │    │  • TPU    │ │
│  │  • APIs      │    │  • Dataflow  │    │  • Rapid     │    │  • Vertex │ │
│  │  • Streaming │    │  • BigFrames │    │    Cache     │    │    AI     │ │
│  │  • Drive     │    │  • Vertex AI │    │  • Rapid     │    │           │ │
│  │              │    │    Pipelines │    │    Bucket    │    │           │ │
│  └──────────────┘    └──────────────┘    └──────────────┘    └───────────┘ │
│                                                                             │
│  ◄── This guide ──────────────────▶     ◄── storage/ guide ──────────────▶ │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key insight**: BigQuery is a serverless analytics data warehouse and preparation engine — it does not mount as a filesystem, serve as a checkpoint target, or stream model weights to accelerators. Those responsibilities belong to the [storage I/O layer](../storage/).

---

## 2. BigQuery Capabilities for AI/ML

| Capability | What It Does | When to Use | Key Links |
|---|---|---|---|
| **BigQuery ML** | Train ML models directly in SQL using `CREATE MODEL`. Supports logistic regression, DNN, boosted trees, AutoML, K-means, matrix factorization, time series, and imported TensorFlow models. | Quick prototyping on tabular data; no GPU needed; models stay in BigQuery or export to GCS for Vertex AI serving. | [BQML overview](https://cloud.google.com/bigquery/docs/bqml-introduction) · [CREATE MODEL syntax](https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-create) |
| **BigQuery DataFrames (bigframes)** | pandas-like + scikit-learn-like Python API powered by BigQuery engine. 750+ APIs with transparent SQL conversion. | Data scientists who prefer pandas workflows at warehouse scale; feature engineering in notebooks before GPU training. | [Introduction](https://cloud.google.com/bigquery/docs/bigquery-dataframes-introduction) · [Quickstart](https://cloud.google.com/bigquery/docs/dataframes-quickstart) · [ML & AI](https://cloud.google.com/bigquery/docs/dataframes-ml-ai) |
| **Export to GCS** | Export tables/query results as Parquet, Avro, CSV, JSON, or TFRecord to Cloud Storage for framework training. | Moving prepared datasets from BigQuery to GCS where GCSFuse or `gcloud storage cp` feeds them to GPUs. | [Export data](https://cloud.google.com/bigquery/docs/exporting-data) · [EXPORT DATA syntax](https://cloud.google.com/bigquery/docs/reference/standard-sql/other-statements#export_data_statement) |
| **Export Models** | Export BQML-trained models as TensorFlow SavedModel or XGBoost Booster to GCS for deployment on Vertex AI or custom serving. | Deploying BQML models to GPU-backed Vertex AI endpoints or TF Serving containers. | [Export models](https://cloud.google.com/bigquery/docs/exporting-models) · [Export & deploy tutorial](https://cloud.google.com/bigquery/docs/export-model-tutorial) |
| **Vertex AI Feature Store integration** | Serve features from BigQuery to online (Bigtable-backed) and offline (BigQuery-backed) stores with automatic sync. | Production ML systems requiring feature consistency between training (BigQuery) and serving (low-latency). | [Feature Store](https://cloud.google.com/vertex-ai/docs/featurestore/overview) · [BigFrames streaming sync](https://cloud.google.com/bigtable/docs/synchronize-with-bigquery-dataframes) |
| **Dataflow templates** | Pre-built Dataflow pipelines: BigQuery → Parquet, BigQuery → TFRecords, with configurable train/test/val splits. | Large-scale ETL (TB+) with automatic sharding; when `EXPORT DATA` isn't sufficient. | [BQ → Parquet](https://cloud.google.com/dataflow/docs/guides/templates/provided/bigquery-to-parquet) · [BQ → TFRecords](https://cloud.google.com/dataflow/docs/guides/templates/provided/bigquery-to-tfrecords) |
| **Vertex AI Pipelines** | Orchestrate end-to-end ML workflows: data prep in BigQuery → training on GPUs → model deployment. | Production ML pipelines with scheduling, lineage tracking, and reproducibility. | [Pipelines overview](https://cloud.google.com/vertex-ai/docs/pipelines/introduction) |

---

## 3. Common Data Pipeline Patterns

| Pattern | Flow | When to Use | Complexity |
|---|---|---|---|
| **SQL-to-Training** | BigQuery → `EXPORT DATA` to GCS (Parquet/CSV) → GCSFuse → GPU training | Structured/tabular data; feature engineering in SQL; one-time or periodic export | Low |
| **Dataflow ETL** | BigQuery → Dataflow template → GCS (TFRecord/Parquet) → GCSFuse → GPU training | Large-scale (TB+) with train/test/val splits; automatic sharding | Medium |
| **BigQuery ML** | Train in BigQuery (SQL `CREATE MODEL`) — no export needed | Quick tabular model prototyping; no GPU required | Low |
| **BQML → Vertex AI** | Train in BQ → `bq extract -m` to GCS → Deploy on Vertex AI endpoint | BQML model → production serving on GPU-backed endpoints | Medium |
| **BigFrames notebook** | `bigframes.pandas` in Colab Enterprise / Vertex AI Notebook → explore → export → train | Data scientists preferring pandas API at BigQuery scale | Low |
| **Feature Hydration** | BigQuery → Vertex AI Feature Store → Online serving (Bigtable) + Offline training (BigQuery) | Production ML with feature consistency across training and serving | High |
| **Continuous sync** | BigQuery → `bigframes.streaming` → Bigtable → low-latency inference | Real-time feature serving from warehouse data | High |

### Example: SQL-to-Training (Most Common)

```sql
-- 1. Prepare features in BigQuery
EXPORT DATA
  OPTIONS (
    uri = 'gs://my-bucket/training-data/output-*.parquet',
    format = 'PARQUET',
    overwrite = true
  )
AS
SELECT
  feature_1,
  feature_2,
  TIMESTAMP_DIFF(event_time, signup_time, HOUR) AS hours_since_signup,
  label
FROM
  `project.dataset.training_table`
WHERE
  split = 'train';
```

```yaml
# 2. Mount in GKE with GCSFuse and train
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: trainer
    image: us-docker.pkg.dev/my-project/ml/trainer:latest
    command: ["python", "train.py", "--data-dir=/data/training-data"]
    resources:
      limits:
        nvidia.com/gpu: "8"
    volumeMounts:
    - name: gcs-data
      mountPath: /data
  volumes:
  - name: gcs-data
    csi:
      driver: gcsfuse.csi.storage.gke.io
      volumeAttributes:
        bucketName: my-bucket
```

---

## 4. BigQuery DataFrames (bigframes)

BigQuery DataFrames provides a familiar pandas + scikit-learn API that pushes computation down to BigQuery — no data movement until you're ready to export.

```python
import bigframes.pandas as bpd

# Connect to BigQuery data — no data leaves BQ
df = bpd.read_gbq("SELECT * FROM `project.dataset.features`")

# Feature engineering with pandas-like API (runs as SQL in BigQuery)
df["feature_ratio"] = df["feature_a"] / df["feature_b"]
df = df.dropna(subset=["label"])

# Preview results
print(df.describe())

# Export to GCS for GPU training
df.to_parquet("gs://my-bucket/prepared-data/features-*.parquet")
```

**Install**: `pip install --upgrade bigframes`

**Required roles**: `roles/bigquery.jobUser`, `roles/bigquery.readSessionUser`

---

## 5. Export Formats & Tooling

| Format | Best For | How to Export | Framework Support |
|---|---|---|---|
| **Parquet** | General-purpose tabular data, columnar compression | `EXPORT DATA FORMAT='PARQUET'` or [Dataflow template](https://cloud.google.com/dataflow/docs/guides/templates/provided/bigquery-to-parquet) | PyTorch (via pandas), JAX, TensorFlow, Spark |
| **TFRecord** | TensorFlow training pipelines | [Dataflow template](https://cloud.google.com/dataflow/docs/guides/templates/provided/bigquery-to-tfrecords) (with train/test/val splits) | TensorFlow, tf.data |
| **CSV / JSON** | Small datasets, human-readable debugging | `EXPORT DATA FORMAT='CSV'` or `FORMAT='JSON'` | All frameworks |
| **Avro** | Schema evolution, BigQuery native format | `EXPORT DATA FORMAT='AVRO'` | Spark, Beam |
| **TF SavedModel** | BQML model export for serving | `bq extract -m` or `EXPORT MODEL` | TensorFlow Serving, Vertex AI |
| **XGBoost Booster** | BQML boosted tree model export | `bq extract -m` | XGBoost, custom serving |

---

## 6. Relationship to Storage I/O Layer

This guide and the [Storage guide](../storage/) are complementary:

| Concern | This Guide (Data Pipeline) | Storage Guide |
|---|---|---|
| **Focus** | Getting data *ready* and *into* GCS | Getting data *from* GCS *to* accelerators |
| **Services** | BigQuery, Dataflow, BigQuery DataFrames, Vertex AI Pipelines | GCSFuse, Rapid Cache, Rapid Bucket, ParallelStore, HyperDisk |
| **Typical bottleneck** | Query/transform time, export bandwidth | Accelerator I/O throughput, pod startup latency |
| **Data direction** | Warehouse/source → GCS | GCS → GPU/TPU memory |

**The handoff point is GCS**: BigQuery prepares and exports data to Cloud Storage buckets. From there, the storage I/O layer (GCSFuse, Rapid Cache, etc.) delivers it to compute at accelerator speed.

> For storage I/O choices after data lands in GCS, see the [Storage for AI Workloads guide](../storage/).

---

> **Disclaimer:** This document is intended for demonstration and enablement purposes. Always follow your organization's security policies and review configurations before deploying in production environments.
