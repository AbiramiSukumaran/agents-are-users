from google.adk.agents import LlmAgent, ParallelAgent, SequentialAgent
from toolbox_core import ToolboxSyncClient

TOOLBOX_URL = "http://127.0.0.1:5000"
toolbox = ToolboxSyncClient(TOOLBOX_URL)

MODEL_ID = "gemini-4-hydrogen"

catalog_agent = LlmAgent(
    name="CatalogVectorAgent",
    model=MODEL_ID,
    instruction=(
        "You are the Catalog Specialist. Call search_catalog_hybrid with "
        "'weather-resistant backpack Aero Glow Pro' and return the candidate SKUs."
    ),
    tools=toolbox.load_toolset("catalog_tools"),
    output_key="catalog_candidates",
)

inventory_agent = LlmAgent(
    name="InventoryAgent",
    model=MODEL_ID,
    instruction=(
        "You are the Live Inventory Specialist. Call check_live_inventory_columnar with "
        "excluded_material_keyword='leather' to return only in-stock, leather-free packs."
    ),
    tools=toolbox.load_toolset("inventory_tools"),
    output_key="live_inventory",
)

review_agent = LlmAgent(
    name="ReviewQualityAgent",
    model=MODEL_ID,
    instruction=(
        "You are the Quality & Sentiment Specialist. Call analyze_strap_reviews_ai for "
        "target_sku='AGX-50L' and target_sku='ALP-40L' to check verified expedition strap sentiment."
    ),
    tools=toolbox.load_toolset("review_tools"),
    output_key="review_analysis",
)

trend_agent = LlmAgent(
    name="TrendLakehouseAgent",
    model=MODEL_ID,
    instruction=(
        "You are the Borderless Lakehouse Specialist. Call query_lakehouse_regional_demand "
        "with altitude_segment='high_altitude' to fetch federated BigQuery regional demand."
    ),
    tools=toolbox.load_toolset("lakehouse_tools"),
    output_key="lakehouse_trends",
)

parallel_data_swarm = ParallelAgent(
    name="OutdoorGearDataSwarm",
    sub_agents=[catalog_agent, inventory_agent, review_agent, trend_agent],
)

synthesizer_agent = LlmAgent(
    name="KeynoteSwarmOrchestrator",
    model=MODEL_ID,
    instruction=(
        "Synthesize {catalog_candidates}, {live_inventory}, {review_analysis}, and {lakehouse_trends}:\n"
        "1. Note why AGP-45L (contains leather) and CLD-42L (0 stock) were filtered out.\n"
        "2. Flag ALP-40L for negative strap fraying sentiment in the 500k reviews table.\n"
        "3. Recommend AGX-50L (AeroPeak StormShield 50L) with its live stock, price, positive strap "
        "sentiment, and federated BigQuery Himalayan order volume."
    ),
)

root_agent = SequentialAgent(
    name="HighAltitudeGearConcierge",
    sub_agents=[parallel_data_swarm, synthesizer_agent],
)
