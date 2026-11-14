| Field | Value |
| --- | --- |
| **id** | agents-are-users-alloydb-lakehouse |
| **summary** | Build a high-concurrency multi-agent swarm using Google ADK, MCP Toolbox for Databases, AlloyDB AI, and BigQuery Borderless Lakehouse Federation. |
| **authors** | Abirami Sukumaran |
| **keywords** | event:GDGCloud2026, docType:KeynoteDemo, category:Cloud, product:AlloyDBForPostgreSQL, product:BigQuery, product:CloudRun, product:VertexAI, product:MCPToolbox |
| **layout** | paginated |

# When Agents Become the Users: In-Database Intelligence & Borderless Analytics

[![AlloyDB AI](https://img.shields.io/badge/Google_Cloud-AlloyDB_AI-4285F4?logo=googlecloud&logoColor=white)](https://cloud.google.com/alloydb/docs/ai/what-is-alloydb-ai)
[![BigQuery Lakehouse](https://img.shields.io/badge/BigQuery-Lakehouse_Federation-34A853?logo=googlecloud&logoColor=white)](https://cloud.google.com/bigquery/docs)
[![MCP Toolbox](https://img.shields.io/badge/MCP_Toolbox-Databases-FBBC04?logo=databricks&logoColor=black)](https://mcp-toolbox.dev/)
[![Google ADK](https://img.shields.io/badge/Agent_Development_Kit-ADK_Swarm-EA4335?logo=google&logoColor=white)](https://github.com/google/adk)

---

## Introduction

For the past thirty years, data architectures were designed around human behavior: one user click resulted in one predictable database query, followed by several seconds of human reading time.

**Today, autonomous AI agent swarms are becoming the primary users of enterprise data.**

Agents do not browse websites—they operate in continuous reasoning loops. A single natural-language user prompt triggers an **Agent Swarm** that bombards your data tier with concurrent point lookups, semantic vector queries, unstructured sentiment evaluations, and analytical scans across cloud borders.

This repository provides the reference implementation demonstrated in the keynote **"When Agents Become the Users: Why Multi-Agent Systems Need In-Database Intelligence and Borderless Analytics"** at GDG Cloud 2026.

### The Impossible User Query

Standard e-commerce architectures fail when handling multi-dimensional reasoning prompts:

> *"I'm planning a high-altitude photography trip. Show me weather-resistant backpacks similar to the Aero Glow Pro, without any leather, confirm they are actually in stock, and tell me if other photographers complained about strap durability in the reviews."*

#### Why Conventional Stacks Break:
* **The Negative Constraint Trap:** Naive vector search embeds *"without leather"* near *"leather"*, recommending leather products.
* **The 20-Minute ETL Lie:** Standalone vector databases syncing on batch schedules report items as in-stock when the transactional OLTP tier has already sold them.
* **The Row-by-Row LLM Tax:** Pulling thousands of review records into client application memory to evaluate sentiment row-by-row creates unacceptable latency and token expense.
* **Cross-Cloud Silos:** Analytics on regional expedition demand live in BigQuery and cross-cloud object storage, inaccessible to transactional APIs without complex pipelines.

---

### What You'll Build

1. **AlloyDB for PostgreSQL Tier:** Configure disaggregated compute/storage with Google ScaNN vector indexing, native BM25 full-text indexing, the dual-format Columnar Engine (100% recall), and in-database SQL AI Functions with **Smart Batching (GA)**.
2. **BigQuery Borderless Lakehouse:** Connect AlloyDB to BigQuery via `bigquery_fdw` to query live analytical demand data with zero ETL and full filter pushdown.
3. **MCP Toolbox for Databases:** Deploy a declarative Model Context Protocol server exposing parameter-safe SQL tools with connection pooling and engine-level security guardrails.
4. **Google ADK Agent System:** Orchestrate four parallel specialist sub-agents powered by **Gemini 4 Hydrogen (`gemini-4-hydrogen`)** using the Google Agent Development Kit (ADK).

---

## Prerequisites

* A Google Cloud project with billing enabled.
* Google Cloud CLI (`gcloud`) installed and authorized.
* Access to Cloud Shell or a Linux/macOS terminal with Python 3.11+.
* Sufficient quota for AlloyDB and Vertex AI.

---

## Step 1: Google Cloud Project Setup & API Enablement
Create your Google Cloud Project and associate it with an active billing account.

## Step 2: Enable required APIs
Enable the necessary APIs:

```bash
gcloud services enable \
  alloydb.googleapis.com \
  aiplatform.googleapis.com \
  bigquery.googleapis.com \
  compute.googleapis.com \
  servicenetworking.googleapis.com \
  secretmanager.googleapis.com \
  run.googleapis.com
```

## Step 3: Setup AlloyDB

* Follow the steps [here](https://github.com/AbiramiSukumaran/polyglot-persist-ecommerce/tree/master#set-up-alloydb)

## Step 4: Initialize Database Schema, Indexes & 500k Reviews

* Follow the steps in the file database-demos.sql in this repo

## Step 5: Configure BigQuery Borderless Lakehouse Federation

* Follow the steps in the file database-demos.sql in this repo

## Step 6: Install and Configure MCP Toolbox for Databases

### **1\. Download the Binary**

In your Cloud Shell TErminal, from your local root directory:

bash

```sh
export VERSION=1.17.0
curl -L -o toolbox https://storage.googleapis.com/genai-toolbox/v$VERSION/linux/amd64/toolbox
chmod +x toolbox
```

### **2\. Clone this Repo**

bash

```sh
git clone https://github.com/AbiramiSukumaran/agents-are-users
```

### **3\. Update `tools.yaml and .env files`**

Update the files tools.yaml and .env with values from your environment

### **4\. Launch and Validate MCP Toolbox**

Start the Toolbox server locally:

bash

```sh
./toolbox --ui
```

Navigate to `http://localhost:5000/ui` to test individual SQL tool endpoints prior to connecting the agent app.


## Step 7: Multi-Agent Application (Google ADK)

This should already be cloned inside the folder swarp_app.

## Step 8: Running the Multi-Agent Application

### **Terminal 1: MCP Toolbox Server**

bash

```sh
./toolbox --ui
```

### **Terminal 2: Google ADK Web UI**

bash

```sh
cd swarm_app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Start the ADK Web server
adk web --port 8000 --allow_origins "*"
```

1. Open `http://localhost:8080` in your browser.  
2. Select **`swarm_app`** from the agent dropdown in the top-left corner.  
3. Paste the prompt:  
   *"I'm planning a high-altitude photography trip. Show me weather-resistant backpacks similar to the Aero Glow Pro, without any leather, confirm they are actually in stock, and tell me if other photographers complained about strap durability in the reviews."*  
4. Click the **Trace / Event Graph** tab to observe all four sub-agents executing concurrently against AlloyDB and BigQuery.


## Step 9: Clean Up
To avoid incurring charges, delete the deployed AlloyDB resources after finishing.
