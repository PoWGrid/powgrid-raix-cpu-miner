#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "=== Packaging PowGrid Reticulum AI (\$RAIX) CPU Miner for HiveOS ==="

PKG_DIR="/tmp/powgrid-raix-cpu-hiveos-build"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/powgrid-raix-cpu-miner"

# Ensure release binary is up to date
cargo build --release

BIN="$DIR/target/release/powgrid-raix-cpu-miner"
cp "$BIN" "$PKG_DIR/powgrid-raix-cpu-miner/"
chmod +x "$PKG_DIR/powgrid-raix-cpu-miner/powgrid-raix-cpu-miner"

# 1. h-manifest.conf
cat << 'EOF' > "$PKG_DIR/powgrid-raix-cpu-miner/h-manifest.conf"
CUSTOM_NAME="powgrid-raix-cpu-miner"
CUSTOM_VERSION="2.2.2"
CUSTOM_BUILD="1"
CUSTOM_LOG_BASENAME="/var/log/miner/$CUSTOM_NAME/$CUSTOM_NAME"
CUSTOM_CONFIG_FILENAME="/hive/miners/custom/$CUSTOM_NAME/powgrid.conf"
CUSTOM_ALGO="randomx"
EOF

# 2. h-config.sh
cat << 'EOF' > "$PKG_DIR/powgrid-raix-cpu-miner/h-config.sh"
#!/usr/bin/env bash
# HiveOS Custom Miner Configuration Generator for PowGrid Reticulum AI ($RAIX) CPU Miner
. `dirname $0`/h-manifest.conf

[[ -z $CUSTOM_TEMPLATE ]] && echo "No wallet address specified" && exit 1

POOL_URL="${CUSTOM_URL:-https://raix.powgrid.xyz}"
if [[ ! $POOL_URL =~ ^http ]]; then
    POOL_URL="https://${POOL_URL}"
fi

WALLET="$CUSTOM_TEMPLATE"
WORKER="${CUSTOM_WORKER:-%WORKER_NAME%}"

mkdir -p $(dirname "$CUSTOM_CONFIG_FILENAME")

cat <<CONFEOF > "$CUSTOM_CONFIG_FILENAME"
POOL_URL="${POOL_URL}"
WALLET="${WALLET}"
WORKER="${WORKER}"
USER_CONFIG="${CUSTOM_USER_CONFIG}"
CONFEOF

echo "PowGrid Reticulum AI CPU Miner HiveOS config generated: $CUSTOM_CONFIG_FILENAME"
EOF

# 3. h-run.sh
cat << 'EOF' > "$PKG_DIR/powgrid-raix-cpu-miner/h-run.sh"
#!/usr/bin/env bash
cd `dirname $0`
. h-manifest.conf

[[ -z $CUSTOM_CONFIG_FILENAME ]] && echo "No config file specified in manifest" && exit 1
[[ ! -f $CUSTOM_CONFIG_FILENAME ]] && echo "Config file $CUSTOM_CONFIG_FILENAME not found" && exit 1

. $CUSTOM_CONFIG_FILENAME

mkdir -p /var/log/miner/$CUSTOM_NAME

ARGS="--pool ${POOL_URL} --wallet ${WALLET} --worker ${WORKER} --hiveos"

if [[ ! -z "$USER_CONFIG" ]]; then
    ARGS="$ARGS $USER_CONFIG"
fi

echo "=========================================================="
echo " Starting PowGrid Reticulum AI (\$RAIX) CPU Miner v${CUSTOM_VERSION}"
echo " Args: $ARGS"
echo "=========================================================="

./powgrid-raix-cpu-miner $ARGS 2>&1 | tee ${CUSTOM_LOG_BASENAME}.log
EOF

# 4. h-stats.sh
cat << 'EOF' > "$PKG_DIR/powgrid-raix-cpu-miner/h-stats.sh"
#!/usr/bin/env bash
cd `dirname $0`
. h-manifest.conf

STATS_FILE="/tmp/powgrid_cpu_miner_stats.json"
[[ ! -f $STATS_FILE ]] && STATS_FILE="/tmp/powgrid_miner_stats.json"

if [[ ! -f $STATS_FILE ]]; then
    stats="null"
    khs=0
    return 0 2>/dev/null || exit 0
fi

eval $(python3 -c "
import json
try:
    with open('$STATS_FILE') as f:
        d = json.load(f)
    uptime = d.get('uptime', 0)
    hs = d.get('hashrate_avg', 0)
    acc = d.get('accepted', 0)
    rej = d.get('rejected', 0)
    print(f'UPTIME={uptime}; HS={hs}; ACC={acc}; REJ={rej};')
except:
    print('UPTIME=0; HS=0; ACC=0; REJ=0;')
")

khs=$(python3 -c "print(round(float('$HS') / 1000.0, 2))" 2>/dev/null || echo 0)

stats=$(python3 -c "
import json
hs_val = float('$HS')
out = {
    'hs': [hs_val],
    'hs_units': 'hs',
    'uptime': int('$UPTIME'),
    'ar': [int('$ACC'), int('$REJ')],
    'algo': 'randomx'
}
print(json.dumps(out))
")
EOF

chmod +x "$PKG_DIR/powgrid-raix-cpu-miner/"*.sh

OUTPUT_ARCHIVE="$DIR/powgrid-raix-cpu-miner-hiveos.tar.gz"
cd "$PKG_DIR"
tar -czf "$OUTPUT_ARCHIVE" powgrid-raix-cpu-miner

echo "✅ HiveOS package created successfully: $OUTPUT_ARCHIVE"
ls -lh "$OUTPUT_ARCHIVE"
tar -ztvf "$OUTPUT_ARCHIVE"
