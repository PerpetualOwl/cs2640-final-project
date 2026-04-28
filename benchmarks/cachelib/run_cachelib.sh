#!/bin/bash
#
# run_cachelib.sh — CacheLib cachebench workloads on NVMe
#
# Usage: ./run_cachelib.sh <nvme_mount> <results_dir>
#
set -euo pipefail

NVME_MOUNT="${1:-/mnt/nvme}"
RESULTS_DIR="${2:-/local/repository/results}"
CACHE_DIR="$NVME_MOUNT/cachelib_data"
CONFIG_DIR="$(cd "$(dirname "$0")" && pwd)/configs"

mkdir -p "$RESULTS_DIR/cachelib" "$CACHE_DIR" "$CONFIG_DIR"

echo "=== CacheLib cachebench ==="
echo "Cache dir: $CACHE_DIR"
echo ""

# Check if cachebench is available
if ! command -v cachebench &> /dev/null; then
    echo "WARNING: cachebench not found in PATH."
    echo "Attempting to locate in build directory..."
    CACHEBENCH=$(find /local/build/CacheLib -name cachebench -type f 2>/dev/null | head -1)
    if [ -z "$CACHEBENCH" ]; then
        echo "ERROR: cachebench binary not found. Skipping CacheLib benchmarks."
        echo "CacheLib build may have failed during setup."
        exit 0
    fi
else
    CACHEBENCH="cachebench"
fi

echo "Using cachebench: $CACHEBENCH"

# -----------------------------------------------------------------------
# Generate cachebench configuration files
# -----------------------------------------------------------------------

# Config 1: Graph Cache Workload (small objects, high hit rate)
cat > "$CONFIG_DIR/graph_cache.json" << 'CACHECONFIG'
{
  "cache_config": {
    "cacheSizeMB": 2048,
    "poolRebalanceIntervalSec": 1,
    "moveOnSlabRelease": false,
    "navyConfig": {
      "fileName": "CACHE_DIR_PLACEHOLDER/navy_graph",
      "raidPaths": [],
      "fileSize": 4294967296,
      "blockSize": 4096,
      "bigHashSizePct": 50,
      "bigHashBucketSize": 4096,
      "smallItemMaxSize": 256
    }
  },
  "test_config": {
    "numOps": 1000000,
    "numThreads": 8,
    "numKeys": 500000,
    "keySizeRange": [8, 64],
    "valSizeRange": [64, 256],
    "getRatio": 0.8,
    "setRatio": 0.15,
    "delRatio": 0.05,
    "keyPoolDistribution": [1.0],
    "opPoolDistribution": [1.0],
    "popularity": "zipf",
    "zipfAlpha": 1.2
  }
}
CACHECONFIG

# Config 2: CDN/Media Cache Workload (large objects, high write rate)
cat > "$CONFIG_DIR/cdn_cache.json" << 'CACHECONFIG'
{
  "cache_config": {
    "cacheSizeMB": 2048,
    "poolRebalanceIntervalSec": 1,
    "moveOnSlabRelease": false,
    "navyConfig": {
      "fileName": "CACHE_DIR_PLACEHOLDER/navy_cdn",
      "raidPaths": [],
      "fileSize": 8589934592,
      "blockSize": 4096,
      "bigHashSizePct": 30,
      "bigHashBucketSize": 4096,
      "smallItemMaxSize": 512
    }
  },
  "test_config": {
    "numOps": 500000,
    "numThreads": 8,
    "numKeys": 200000,
    "keySizeRange": [16, 64],
    "valSizeRange": [1024, 65536],
    "getRatio": 0.3,
    "setRatio": 0.65,
    "delRatio": 0.05,
    "keyPoolDistribution": [1.0],
    "opPoolDistribution": [1.0],
    "popularity": "zipf",
    "zipfAlpha": 0.9
  }
}
CACHECONFIG

# Config 3: KV Store Workload (mixed sizes, balanced R/W)
cat > "$CONFIG_DIR/kv_store.json" << 'CACHECONFIG'
{
  "cache_config": {
    "cacheSizeMB": 2048,
    "poolRebalanceIntervalSec": 1,
    "moveOnSlabRelease": false,
    "navyConfig": {
      "fileName": "CACHE_DIR_PLACEHOLDER/navy_kv",
      "raidPaths": [],
      "fileSize": 4294967296,
      "blockSize": 4096,
      "bigHashSizePct": 40,
      "bigHashBucketSize": 4096,
      "smallItemMaxSize": 512
    }
  },
  "test_config": {
    "numOps": 1000000,
    "numThreads": 8,
    "numKeys": 500000,
    "keySizeRange": [8, 128],
    "valSizeRange": [64, 16384],
    "getRatio": 0.5,
    "setRatio": 0.4,
    "delRatio": 0.1,
    "keyPoolDistribution": [1.0],
    "opPoolDistribution": [1.0],
    "popularity": "zipf",
    "zipfAlpha": 1.0
  }
}
CACHECONFIG

# Replace placeholder with actual cache directory
sed -i "s|CACHE_DIR_PLACEHOLDER|$CACHE_DIR|g" "$CONFIG_DIR"/*.json

# -----------------------------------------------------------------------
# Run workloads
# -----------------------------------------------------------------------

echo "--- [1/3] Graph Cache Workload (small objects, read-heavy) ---"
rm -rf "$CACHE_DIR"/*
$CACHEBENCH --json_test_config "$CONFIG_DIR/graph_cache.json" \
    2>&1 | tee "$RESULTS_DIR/cachelib/graph_cache.log"
echo ""

echo "--- [2/3] CDN Cache Workload (large objects, write-heavy) ---"
rm -rf "$CACHE_DIR"/*
$CACHEBENCH --json_test_config "$CONFIG_DIR/cdn_cache.json" \
    2>&1 | tee "$RESULTS_DIR/cachelib/cdn_cache.log"
echo ""

echo "--- [3/3] KV Store Workload (mixed sizes, balanced R/W) ---"
rm -rf "$CACHE_DIR"/*
$CACHEBENCH --json_test_config "$CONFIG_DIR/kv_store.json" \
    2>&1 | tee "$RESULTS_DIR/cachelib/kv_store.log"
echo ""

echo "=== CacheLib benchmarks complete ==="
