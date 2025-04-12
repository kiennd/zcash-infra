# Scripts for Zcash Infrastructure

This directory contains utility scripts that complement the Zcash infrastructure
setup. These scripts automate various tasks and provide additional functionality
to the core components.

## Available Scripts

### zcash-exporter.py

A Prometheus exporter for Zcash node metrics. This script polls a Zcash node via
its JSON-RPC API and exposes metrics in a format that Prometheus can scrape.

**Features:**
- Exposes blockchain information (block height, difficulty, verification progress)
- Provides network statistics (connections, version)
- Reports memory usage (used, free, total)
- Shows mempool information (size, transactions, memory usage)
- Includes mining statistics (network hash rate, difficulty)
- Monitors latest block details (size, timestamp, transaction count)

**Requirements:**
- Python 3.6+
- `requests` library

**Configuration:**
The script is configured through environment variables:
- `ZCASH_HOST`: Hostname of the Zcash node (default: "zcashd")
- `ZCASH_PORT`: RPC port of the Zcash node (default: "8232")
- `ZCASH_RPC_USER`: RPC username for authentication
- `ZCASH_RPC_PASSWORD`: RPC password for authentication
- `EXPORTER_PORT`: Port on which the exporter listens (default: "9101")
- `REFRESH_INTERVAL`: Seconds between metric refreshes (default: "60")

**Usage:**
```bash
# Install dependencies
pip install requests

# Run the exporter
python zcash-exporter.py
```

The metrics will be available at http://localhost:9101/metrics.

**Integration with Prometheus:**
Add the following to your Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'zcash'
    static_configs:
      - targets: ['zcash-exporter:9101']
```

## Adding New Scripts

When adding new scripts to this directory:

1. Make sure the script is well-documented with comments
2. Add a description of the script to this README
3. Include usage examples and configuration options
4. Specify any dependencies required to run the script
5. Make the script executable with `chmod +x script_name.py`