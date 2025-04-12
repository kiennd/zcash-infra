#!/usr/bin/env python3
"""
Zcash Metrics Exporter for Prometheus
This script queries a Zcash node via RPC and exposes metrics for Prometheus to scrape.
"""

import json
import time
import os
import sys
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
import requests
from requests.auth import HTTPBasicAuth

# Configuration
ZCASH_HOST = os.getenv("ZCASH_HOST", "zcashd")
ZCASH_PORT = os.getenv("ZCASH_PORT", "8232")
ZCASH_RPC_USER = os.getenv("ZCASH_RPC_USER", "")
ZCASH_RPC_PASSWORD = os.getenv("ZCASH_RPC_PASSWORD", "")
EXPORTER_PORT = int(os.getenv("EXPORTER_PORT", "9101"))
REFRESH_INTERVAL = int(os.getenv("REFRESH_INTERVAL", "60"))

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("zcash-exporter")

# Global metrics cache
metrics_cache = {}
last_update_time = 0


def call_zcash_rpc(method, params=None):
    """Call Zcash RPC method with given parameters."""
    if params is None:
        params = []

    url = f"http://{ZCASH_HOST}:{ZCASH_PORT}"
    headers = {"content-type": "application/json"}
    payload = {
        "jsonrpc": "1.0",
        "id": "zcash-exporter",
        "method": method,
        "params": params,
    }

    try:
        response = requests.post(
            url,
            data=json.dumps(payload),
            headers=headers,
            auth=HTTPBasicAuth(ZCASH_RPC_USER, ZCASH_RPC_PASSWORD),
            timeout=10,
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"Error calling RPC {method}: {str(e)}")
        return None


def get_metrics():
    """Collect all metrics from Zcash node."""
    metrics = {}

    # Get blockchain info
    blockchain_info = call_zcash_rpc("getblockchaininfo")
    if blockchain_info and "result" in blockchain_info:
        result = blockchain_info["result"]
        metrics["zcash_blocks"] = result.get("blocks", 0)
        metrics["zcash_difficulty"] = result.get("difficulty", 0)
        metrics["zcash_verificationprogress"] = result.get("verificationprogress", 0)
        metrics["zcash_size_on_disk"] = result.get("size_on_disk", 0)
        metrics["zcash_pruned"] = 1 if result.get("pruned", False) else 0

    # Get network info
    network_info = call_zcash_rpc("getnetworkinfo")
    if network_info and "result" in network_info:
        result = network_info["result"]
        metrics["zcash_connections"] = result.get("connections", 0)
        metrics["zcash_version"] = result.get("version", 0)
        metrics["zcash_protocol_version"] = result.get("protocolversion", 0)
        metrics["zcash_relay_fee"] = result.get("relayfee", 0)

    # Get peer info
    peer_info = call_zcash_rpc("getpeerinfo")
    if peer_info and "result" in peer_info:
        peers = peer_info["result"]
        # Store peer IP addresses as labels in a single metric
        peer_addresses = []
        for i, peer in enumerate(peers):
            addr = peer.get("addr", "").split(":")[0]  # Strip port number
            if addr:
                peer_addresses.append(addr)
        # Join peer addresses with | delimiter for easier parsing in Grafana
        metrics["zcash_peer_addresses"] = "|".join(peer_addresses)

    # Get memory info
    memory_info = call_zcash_rpc("getmemoryinfo")
    if memory_info and "result" in memory_info:
        result = memory_info["result"]
        if "locked" in result:
            metrics["zcash_memory_used"] = result["locked"].get("used", 0)
            metrics["zcash_memory_free"] = result["locked"].get("free", 0)
            metrics["zcash_memory_total"] = result["locked"].get("total", 0)

    # Get mempool info
    mempool_info = call_zcash_rpc("getmempoolinfo")
    if mempool_info and "result" in mempool_info:
        result = mempool_info["result"]
        metrics["zcash_mempool_size"] = result.get("size", 0)
        metrics["zcash_mempool_bytes"] = result.get("bytes", 0)
        metrics["zcash_mempool_usage"] = result.get("usage", 0)

    # Get mining info
    mining_info = call_zcash_rpc("getmininginfo")
    if mining_info and "result" in mining_info:
        result = mining_info["result"]
        metrics["zcash_network_hashps"] = result.get("networkhashps", 0)
        metrics["zcash_network_difficulty"] = result.get("difficulty", 0)

    # Get latest block details
    if "zcash_blocks" in metrics and metrics["zcash_blocks"] > 0:
        block_hash = call_zcash_rpc("getblockhash", [metrics["zcash_blocks"]])
        if block_hash and "result" in block_hash:
            block_info = call_zcash_rpc("getblock", [block_hash["result"]])
            if block_info and "result" in block_info:
                result = block_info["result"]
                metrics["zcash_latest_block_size"] = result.get("size", 0)
                metrics["zcash_latest_block_timestamp"] = result.get("time", 0)
                metrics["zcash_latest_block_transactions"] = len(result.get("tx", []))

    return metrics


def format_metrics(metrics):
    """Format metrics in Prometheus format."""
    output = []
    for k, v in metrics.items():
        if k == "zcash_peer_addresses":
            # Special handling for peer addresses (string)
            output.append(f"# HELP {k} List of Zcash peer IP addresses")
            output.append(f"# TYPE {k} gauge")
            output.append(f'{k}{{addresses="{v}"}} 1')
        elif isinstance(v, (int, float)):
            output.append(f"# HELP {k} Zcash metric {k}")
            output.append(f"# TYPE {k} gauge")
            output.append(f"{k} {v}")
    return "\n".join(output)


class PrometheusExporter(BaseHTTPRequestHandler):
    def do_GET(self):
        global metrics_cache, last_update_time

        if self.path == "/metrics":
            # Check if we need to refresh metrics
            current_time = time.time()
            if current_time - last_update_time > REFRESH_INTERVAL:
                try:
                    metrics_cache = get_metrics()
                    last_update_time = current_time
                    logger.info("Metrics refreshed successfully")
                except Exception as e:
                    logger.error(f"Error refreshing metrics: {str(e)}")

            # Send response
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(format_metrics(metrics_cache).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress HTTP server logs
        return


def main():
    try:
        # Initial metrics collection
        metrics_cache.update(get_metrics())
        global last_update_time
        last_update_time = time.time()

        # Start HTTP server
        server = HTTPServer(("0.0.0.0", EXPORTER_PORT), PrometheusExporter)
        logger.info(f"Starting Zcash Exporter on port {EXPORTER_PORT}")
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Exiting on user interrupt")
    except Exception as e:
        logger.error(f"Error in main loop: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
