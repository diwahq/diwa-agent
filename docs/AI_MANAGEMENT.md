# AI Management & Billing (Phase 4B)

## Overview

Diwa's AI Management layer provides robust tracking, billing, and secure configuration for AI model usage. This system ensures that all AI interactions are monitored for cost and performance, and that sensitive API keys are managed securely.

## Components

### 1. Usage Tracking (`lib/diwa/accounting/usage_tracker.ex`)

- **Telemetry Integration**: Listens for `[:diwa, :ai, :usage]` events emitted by AI providers.
- **Asynchronous Processing**: Records usage data via `Task` to avoid blocking the main application flow.
- **Data Persistence**: Stores detailed records in the `usage_records` table.
- **Metrics**: Tracks input tokens, output tokens, total tokens, duration, and estimated cost.

### 2. Pricing Engine (`lib/diwa/accounting/pricing.ex`)

- **Cost Calculation**: Estimates costs based on provider models (e.g., GPT-4, GPT-3.5).
- **Unit**: Costs are calculated in **USD** (stored as `decimal`).
- **Supported Models**: Includes predefined pricing for common OpenAI models. Defaulting to 0 for unknown models.

### 3. Secure Configuration (`lib/diwa/configuration.ex`)

- **Secret Management**: Provides a secure way to store and retrieve sensitive API keys (e.g., `openai_api_key`).
- **Encryption**: Uses **AES-256-GCM** encryption for data at rest in the `secrets` table.
- **Key Derivation**: Uses the application's `secret_key_base` to derive the encryption key.
- **"Bring Your Own Key"**: Enables dynamic, per-user or per-organization API key configuration via UI, overriding static environment variables.

### 4. AI Providers (`lib/diwa/ai/providers/*.ex`)

- **Dynamic Key Loading**: Providers (`OpenAI`, `Anthropic`) now check:
    1. Runtime options (`opts`)
    2. Environment variables (`Application.get_env`)
    3. **Secure Secrets Store (`Diwa.Configuration.get_secret`)**
- **Resilience**: Integrated `Req` retry mechanisms for transient network errors.

## Usage

### Recording a Secret (Elixir Console)

```elixir
Diwa.Configuration.save_secret("openai_api_key", "sk-proj-...")
```

### Retrieving Usage Stats

```elixir
Diwa.Accounting.Usage.get_context_usage(context_id)
# => %{count: 150, tokens: 45000, cost: #Decimal<0.15>}
```

## Database Schema

### `usage_records`

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `binary_id` | Unique ID |
| `context_id` | `binary_id` | Linked Context (Project) |
| `provider` | `string` | e.g. "Elixir.Diwa.AI.Providers.OpenAI" |
| `model` | `string` | e.g. "gpt-4" |
| `operation` | `string` | "complete" or "embed" |
| `tokens_input` | `integer` | Prompt tokens |
| `tokens_output` | `integer` | Completion tokens |
| `total_tokens` | `integer` | Total tokens |
| `cost_estimate` | `decimal` | Estimated cost in USD |
| `duration_ms` | `integer` | Latency in milliseconds |

### `secrets`

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `binary_id` | Unique ID |
| `key` | `string` | Lookup key (e.g. "openai_api_key") |
| `value_encrypted` | `binary` | Encrypted value |

## Future Work

- **UI Integration**:
    - Settings page for managing API keys.
    - Dashboard for visualizing usage and costs.
- **Quota Management**: Implementing budget caps per context or user.
