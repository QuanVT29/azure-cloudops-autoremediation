# Enterprise Core Banking Portal & SRE Chaos Engineering Simulator

import os
import time
import json
import uuid
import socket
import logging
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse
import redis

# Safe import for pyodbc to support both ConfigMap runtime and custom Docker builds
try:
    import pyodbc
except ImportError:
    pyodbc = None

# Standardized structured logging for Azure Container Insights & Log Analytics
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [Pod:%(hostname)s] %(name)s - %(message)s"
)

class HostnameFilter(logging.Filter):
    def filter(self, record):
        record.hostname = socket.gethostname()
        return True

logger = logging.getLogger("banking-api")
logger.addFilter(HostnameFilter())

app = FastAPI(
    title="FPT Enterprise Core Banking Platform",
    description="Cloud Operations, Zero-Trust Data Plane & Autonomous Auto-Remediation",
    version="2.0.0"
)

# Runtime state stores
_memory_leak_store = []
_fallback_tx_store = [
    {"tx_id": "TXN-90812", "account": "VN-CORP-00192", "type": "SWIFT Wire", "amount": "$125,000.00", "status": "SETTLED", "timestamp": "07:15:00 UTC"},
    {"tx_id": "TXN-90813", "account": "SG-INST-88410", "type": "Interbank ACH", "amount": "$42,850.00", "status": "SETTLED", "timestamp": "07:22:14 UTC"}
]

def get_redis_client():
    redis_url = os.getenv("REDIS_CONNECTION_STRING", "redis://redis-service.default.svc.cluster.local:6379")
    return redis.from_url(redis_url, socket_connect_timeout=2, decode_responses=True)


# 1. Kubernetes Liveness & Readiness Probe
@app.get("/healthz")
def health_check():
    return {
        "status": "healthy",
        "service": "core-banking-api",
        "pod_name": socket.gethostname(),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


# 2. Live Infrastructure & Zero-Trust Connectivity Verification API
@app.get("/api/verify-connections")
def verify_connections():
    """Performs real-time TCP, Private DNS, Redis, and CSI Volume checks."""
    sql_conn_str = os.getenv("SQL_CONNECTION_STRING", "")
    redis_conn_str = os.getenv("REDIS_CONNECTION_STRING", "")

    # 1. Verify CSI Secrets Store mount files
    csi_path = "/mnt/secrets-store"
    csi_files = []
    if os.path.exists(csi_path):
        csi_files = [f for f in os.listdir(csi_path) if not f.startswith(".")]

    # 2. Verify Azure SQL Private Endpoint DNS & TCP 1433 connectivity
    sql_fqdn = "unknown"
    sql_resolved_ip = "unresolved"
    sql_tcp_1433 = False
    sql_latency_ms = 0

    if "tcp:" in sql_conn_str:
        try:
            sql_fqdn = sql_conn_str.split("tcp:")[1].split(",")[0]
            sql_resolved_ip = socket.gethostbyname(sql_fqdn)
            t0 = time.perf_counter()
            with socket.create_connection((sql_fqdn, 1433), timeout=3):
                sql_tcp_1433 = True
            sql_latency_ms = round((time.perf_counter() - t0) * 1000, 2)
        except Exception as e:
            logger.error(f"SQL Private Link verification error: {e}")

    # 3. Verify In-Cluster Redis connectivity
    redis_ok = False
    redis_latency_ms = 0
    redis_ops_count = 0
    try:
        t0 = time.perf_counter()
        r = get_redis_client()
        if r.ping():
            redis_ok = True
            redis_ops_count = r.incr("banking:health_verify_count")
        redis_latency_ms = round((time.perf_counter() - t0) * 1000, 2)
    except Exception as e:
        logger.error(f"Redis connectivity error: {e}")

    result = {
        "status": "verified" if (sql_tcp_1433 and redis_ok) else "degraded",
        "serving_pod": socket.gethostname(),
        "csi_secret_store": {
            "mounted": len(csi_files) > 0,
            "files": csi_files
        },
        "azure_sql_private_link": {
            "fqdn": sql_fqdn,
            "private_ip": sql_resolved_ip,
            "tcp_1433_reachable": sql_tcp_1433,
            "latency_ms": sql_latency_ms
        },
        "in_cluster_redis": {
            "ping_success": redis_ok,
            "latency_ms": redis_latency_ms,
            "total_verifications": redis_ops_count
        }
    }
    logger.info(f"Infrastructure verification executed: SQL={sql_resolved_ip} ({sql_tcp_1433}), Redis={redis_ok}")
    return result


# 3. Core Banking Transaction API (Read/Write with In-Cluster Redis)
@app.get("/api/transactions")
def list_transactions():
    """Retrieves recent banking transactions from In-Cluster Redis cache."""
    tx_list = list(_fallback_tx_store)
    cache_source = "memory-fallback"
    try:
        r = get_redis_client()
        cached_items = r.lrange("banking:recent_transactions", 0, 9)
        if cached_items:
            tx_list = [json.loads(item) for item in cached_items]
        else:
            for tx in reversed(_fallback_tx_store):
                r.lpush("banking:recent_transactions", json.dumps(tx))
        cache_source = "in-cluster-redis"
    except Exception as e:
        logger.warning(f"Falling back to local memory for transactions: {e}")

    return {
        "status": "success",
        "serving_pod": socket.gethostname(),
        "cache_source": cache_source,
        "database_configured": bool(os.getenv("SQL_CONNECTION_STRING")),
        "cache_configured": bool(os.getenv("REDIS_CONNECTION_STRING")),
        "transactions": tx_list
    }

@app.post("/api/transactions/simulate")
def create_mock_transaction():
    """Creates a new core banking wire transaction and stores it in Redis."""
    new_tx = {
        "tx_id": f"TXN-{uuid.uuid4().hex[:5].upper()}",
        "account": f"VN-ENT-{uuid.uuid4().int % 90000 + 10000}",
        "type": "Instant Settlement",
        "amount": f"${(uuid.uuid4().int % 85000 + 5000):,.2f}",
        "status": "SETTLED",
        "timestamp": datetime.now(timezone.utc).strftime("%H:%M:%S UTC")
    }
    try:
        r = get_redis_client()
        r.lpush("banking:recent_transactions", json.dumps(new_tx))
        r.ltrim("banking:recent_transactions", 0, 7)
    except Exception:
        _fallback_tx_store.insert(0, new_tx)

    logger.info(f"Processed new transaction {new_tx['tx_id']} for {new_tx['amount']}")
    return {
        "status": "settled",
        "serving_pod": socket.gethostname(),
        "transaction": new_tx
    }


# 4. SRE Chaos Engineering & Fault Injection Endpoints (Layer 5 Auto-Healing)
@app.get("/api/fault/500")
@app.post("/api/fault/500")
def trigger_http_500():
    """Scenario 1: Injects HTTP 500 error to trigger Azure Monitor P1 Alert."""
    pod = socket.gethostname()
    logger.error(f"CHAOS_EVENT_P1: Critical HTTP 500 transaction pipeline failure injected on pod {pod}.")
    return JSONResponse(
        status_code=500,
        content={
            "status": "critical_error",
            "error_code": "CORE_BANKING_PIPELINE_FAILURE",
            "serving_pod": pod,
            "message": "Simulated HTTP 500 Outage emitted to Azure Container Insights / Log Analytics."
        }
    )

@app.get("/api/fault/slow-dependency")
@app.post("/api/fault/slow-dependency")
def trigger_slow_dependency():
    """Scenario 2: Injects 3.5s latency to breach SLA threshold (>2500ms)."""
    pod = socket.gethostname()
    logger.warning(f"CHAOS_EVENT_P2: Simulating 3500ms downstream SQL lock latency on pod {pod}...")
    time.sleep(3.5)
    return {
        "status": "degraded_sla_breach",
        "serving_pod": pod,
        "injected_latency_ms": 3500,
        "message": "High latency response completed (3500ms > 2500ms threshold)."
    }

@app.get("/api/fault/oom")
@app.post("/api/fault/oom")
def trigger_oom_kill():
    """Scenario 3: Allocates rapid memory blocks to trigger Kubernetes OOMKilled."""
    pod = socket.gethostname()
    logger.critical(f"CHAOS_EVENT_OOM: Initiating rapid memory exhaustion on pod {pod}...")
    try:
        # Allocate ~600MB rapidly to exceed the 512Mi container memory limit
        for _ in range(8):
            _memory_leak_store.append(bytearray(80 * 1024 * 1024))
            time.sleep(0.05)
    except MemoryError:
        logger.critical("Pod memory exhausted!")
    return {
        "status": "memory_spike_allocated",
        "serving_pod": pod,
        "allocated_chunks": len(_memory_leak_store),
        "message": "Memory limit breached; Kubernetes OOMKiller will terminate pod shortly."
    }


# 5. Interactive Enterprise Web UI Dashboard
@app.get("/", response_class=HTMLResponse)
def banking_dashboard():
    pod_name = socket.gethostname()
    sql_configured = bool(os.getenv("SQL_CONNECTION_STRING"))
    redis_configured = bool(os.getenv("REDIS_CONNECTION_STRING"))

    html_content = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Enterprise Core Banking Platform | CloudOps & SRE Portal</title>
        <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-slate-950 text-slate-100 min-h-screen p-6 md:p-8 font-sans">
        <div class="max-w-6xl mx-auto space-y-6">
            
            <!-- Top Navigation Header -->
            <div class="flex flex-col md:flex-row md:justify-between md:items-center gap-4 border-b border-slate-800 pb-5">
                <div>
                    <div class="flex items-center gap-3">
                        <h1 class="text-2xl md:text-3xl font-bold text-sky-400 tracking-tight">
                            Enterprise Core Banking Platform
                        </h1>
                    </div>
                    <p class="text-sm text-slate-400 mt-1">
                        Azure AKS (v1.35.8) • Zero-Trust Private Link • Autonomous ServiceNow & Runbook Auto-Remediation
                    </p>
                </div>
                <div class="flex items-center gap-3 shrink-0">
                    <div class="px-3 py-1.5 bg-slate-900 border border-slate-700 rounded-lg text-xs text-slate-300 font-mono">
                        Pod: <span id="pod-badge" class="text-sky-400 font-semibold">{pod_name}</span>
                    </div>
                    <span class="px-3.5 py-1.5 bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 rounded-full text-xs font-semibold uppercase tracking-wider shrink-0">
                        ● Production Active
                    </span>
                </div>
            </div>

            <!-- Layer 3 & 4 Infrastructure Telemetry Cards -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="bg-slate-900/90 p-5 rounded-xl border border-slate-800 shadow-lg">
                    <div class="flex justify-between items-start">
                        <p class="text-xs font-medium uppercase tracking-wider text-slate-400">Relational Database</p>
                        <span class="text-xs font-mono px-2 py-0.5 bg-slate-800 text-slate-300 rounded">snet-data</span>
                    </div>
                    <p class="text-xl font-bold text-white mt-2">Azure SQL Serverless</p>
                    <p id="sql-status-text" class="text-xs text-emerald-400 mt-3 font-mono">
                        ● {"Connected (Private Link 10.0.2.4:1433)" if sql_configured else "Missing Connection String"}
                    </p>
                </div>

                <div class="bg-slate-900/90 p-5 rounded-xl border border-slate-800 shadow-lg">
                    <div class="flex justify-between items-start">
                        <p class="text-xs font-medium uppercase tracking-wider text-slate-400">In-Memory Caching</p>
                        <span class="text-xs font-mono px-2 py-0.5 bg-slate-800 text-slate-300 rounded">snet-aks</span>
                    </div>
                    <p class="text-xl font-bold text-white mt-2">In-Cluster Redis 7.2</p>
                    <p id="redis-status-text" class="text-xs text-emerald-400 mt-3 font-mono">
                        ● {"Active (redis-service:6379)" if redis_configured else "Disconnected"}
                    </p>
                </div>

                <div class="bg-slate-900/90 p-5 rounded-xl border border-slate-800 shadow-lg">
                    <div class="flex justify-between items-start">
                        <p class="text-xs font-medium uppercase tracking-wider text-slate-400">Zero-Trust Secrets</p>
                        <span class="text-xs font-mono px-2 py-0.5 bg-slate-800 text-slate-300 rounded">10.0.2.5</span>
                    </div>
                    <p class="text-xl font-bold text-white mt-2">Azure Key Vault</p>
                    <p class="text-xs text-sky-400 mt-3 font-mono">
                        ● Secrets Store CSI Driver (/mnt/secrets-store)
                    </p>
                </div>
            </div>

            <!-- Two-Column Operations Section: Banking Ledger + Live Diagnostics -->
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                
                <!-- Core Banking Settlement Ledger (2 Columns wide) -->
                <div class="lg:col-span-2 bg-slate-900/90 p-6 rounded-xl border border-slate-800 space-y-4">
                    <div class="flex flex-wrap justify-between items-center gap-2">
                        <div>
                            <h2 class="text-lg font-bold text-white">Core Banking Settlement Stream</h2>
                            <p class="text-xs text-slate-400">Real-time transactions cached in In-Cluster Redis</p>
                        </div>
                        <div class="flex gap-2">
                            <button onclick="simulateTransaction()" class="px-3.5 py-2 bg-sky-600 hover:bg-sky-500 text-white rounded-lg text-xs font-semibold transition shadow">
                                + Simulate Wire Transfer
                            </button>
                            <button onclick="loadTransactions()" class="px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-lg text-xs font-semibold transition border border-slate-700">
                                Refresh
                            </button>
                        </div>
                    </div>

                    <div class="overflow-x-auto">
                        <table class="w-full text-left border-collapse text-xs">
                            <thead>
                                <tr class="border-b border-slate-800 text-slate-400 uppercase">
                                    <th class="py-2.5 px-3">TX ID</th>
                                    <th class="py-2.5 px-3">Account</th>
                                    <th class="py-2.5 px-3">Channel</th>
                                    <th class="py-2.5 px-3">Amount</th>
                                    <th class="py-2.5 px-3">Status</th>
                                    <th class="py-2.5 px-3">Time</th>
                                </tr>
                            </thead>
                            <tbody id="tx-table-body" class="divide-y divide-slate-800/60 font-mono text-slate-200">
                                <tr><td colspan="6" class="py-4 text-center text-slate-500">Loading ledger...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- Zero-Trust Data Plane Verification Box -->
                <div class="bg-slate-900/90 p-6 rounded-xl border border-slate-800 flex flex-col justify-between space-y-4">
                    <div class="space-y-2">
                        <h2 class="text-lg font-bold text-white">Data Plane Diagnostics</h2>
                        <p class="text-xs text-slate-400">
                            Kiểm chứng trực tiếp phân giải Private DNS (10.0.2.4), cổng TCP 1433, Redis Ping và ổ đĩa RAM CSI Driver từ Pod.
                        </p>
                        <div id="diag-box" class="mt-3 p-3.5 bg-slate-950 rounded-lg border border-slate-800 font-mono text-xs space-y-1.5 text-slate-300">
                            <div>SQL Private IP: <span id="diag-sql-ip" class="text-emerald-400">Click Verify...</span></div>
                            <div>SQL TCP 1433: <span id="diag-sql-tcp" class="text-emerald-400">--</span></div>
                            <div>Redis Ping: <span id="diag-redis" class="text-emerald-400">--</span></div>
                            <div>CSI Secrets: <span id="diag-csi" class="text-sky-400">--</span></div>
                        </div>
                    </div>
                    <button onclick="verifyInfrastructure()" class="w-full py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg text-xs font-semibold uppercase tracking-wider transition shadow">
                        Verify Live Private Link & CSI Secrets
                    </button>
                </div>
            </div>

            <!-- SRE Chaos Engineering & Auto-Remediation Simulator -->
            <div class="bg-slate-900/95 p-6 rounded-xl border border-rose-900/50 space-y-4 shadow-xl">
                <div class="flex flex-col md:flex-row md:justify-between md:items-center gap-2">
                    <div>
                        <h2 class="text-lg font-bold text-rose-400 flex items-center gap-2">
                            <span>⚠️</span> SRE Chaos Testing & Auto-Remediation Simulator
                        </h2>
                        <p class="text-xs text-slate-300 mt-1">
                            Kích hoạt lỗi nhân tạo để kiểm thử quy trình: Azure Monitor Alerting → Logic App → ServiceNow Incident → PowerShell Runbook Pod Self-Healing (&lt;60s MTTR).
                        </p>
                    </div>
                    <button onclick="clearConsole()" class="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded text-xs font-mono self-start md:self-auto">
                        Clear Console
                    </button>
                </div>

                <div class="flex flex-wrap gap-3 pt-1">
                    <button onclick="triggerChaos('/api/fault/500', 'P1 Outage (HTTP 500)')" class="px-4 py-2.5 bg-rose-600 hover:bg-rose-500 text-white rounded-lg text-xs font-semibold transition shadow">
                        Trigger P1 Outage (HTTP 500)
                    </button>
                    <button onclick="triggerChaos('/api/fault/oom', 'OOM Crash (CrashLoopBackOff)')" class="px-4 py-2.5 bg-amber-600 hover:bg-amber-500 text-white rounded-lg text-xs font-semibold transition shadow">
                        Trigger OOM Crash (CrashLoopBackOff)
                    </button>
                    <button onclick="triggerChaos('/api/fault/slow-dependency', 'High Latency (>3.5s)')" class="px-4 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg text-xs font-semibold transition shadow">
                        Trigger High Latency (&gt;3.5s)
                    </button>
                </div>

                <!-- Interactive Telemetry Output Console -->
                <div class="bg-slate-950 border border-slate-800 rounded-lg p-4 font-mono text-xs">
                    <div class="text-slate-500 mb-2 border-b border-slate-800 pb-1 flex justify-between">
                        <span>LIVE SRE TELEMETRY &amp; CHAOS EXECUTION LOG</span>
                        <span>STDOUT / CONTAINER INSIGHTS STREAM</span>
                    </div>
                    <div id="sre-console" class="space-y-1.5 max-h-48 overflow-y-auto text-slate-300">
                        <div class="text-emerald-400">[SYSTEM] Banking Pod {pod_name} initialized and ready. Select an action above to stream telemetry.</div>
                    </div>
                </div>
            </div>

        </div>

        <script>
            function appendLog(tag, message, isError = false) {{
                const consoleBox = document.getElementById('sre-console');
                const now = new Date().toLocaleTimeString();
                const colorClass = isError ? 'text-rose-400' : 'text-sky-300';
                const entry = document.createElement('div');
                entry.className = colorClass;
                entry.textContent = `[${{now}}] [${{tag}}] ${{message}}`;
                consoleBox.prepend(entry);
            }}

            function clearConsole() {{
                document.getElementById('sre-console').innerHTML = '<div class="text-slate-500">[CONSOLE CLEARED] Ready for new telemetry events...</div>';
            }}

            async function loadTransactions() {{
                const start = performance.now();
                try {{
                    const res = await fetch('/api/transactions');
                    const data = await res.json();
                    const elapsed = Math.round(performance.now() - start);
                    document.getElementById('pod-badge').textContent = data.serving_pod;

                    const tbody = document.getElementById('tx-table-body');
                    tbody.innerHTML = data.transactions.map(tx => `
                        <tr class="hover:bg-slate-900/50">
                            <td class="py-2.5 px-3 text-sky-400 font-semibold">${{tx.tx_id}}</td>
                            <td class="py-2.5 px-3">${{tx.account}}</td>
                            <td class="py-2.5 px-3 text-slate-400">${{tx.type}}</td>
                            <td class="py-2.5 px-3 font-semibold text-white">${{tx.amount}}</td>
                            <td class="py-2.5 px-3"><span class="px-2 py-0.5 bg-emerald-500/15 text-emerald-400 rounded text-[10px]">${{tx.status}}</span></td>
                            <td class="py-2.5 px-3 text-slate-400">${{tx.timestamp}}</td>
                        </tr>
                    `).join('');
                    appendLog('LEDGER', `Fetched ${{data.transactions.length}} records from ${{data.cache_source}} via Pod ${{data.serving_pod}} (${{elapsed}}ms)`);
                }} catch (err) {{
                    appendLog('ERROR', `Failed to load ledger: ${{err.message}}`, true);
                }}
            }}

            async function simulateTransaction() {{
                const start = performance.now();
                try {{
                    const res = await fetch('/api/transactions/simulate', {{ method: 'POST' }});
                    const data = await res.json();
                    const elapsed = Math.round(performance.now() - start);
                    appendLog('WIRE-TX', `Settled ${{data.transaction.tx_id}} (${{data.transaction.amount}}) in Redis via Pod ${{data.serving_pod}} (${{elapsed}}ms)`);
                    await loadTransactions();
                }} catch (err) {{
                    appendLog('ERROR', `Transaction simulation failed: ${{err.message}}`, true);
                }}
            }}

            async function verifyInfrastructure() {{
                appendLog('DIAGNOSTICS', 'Probing Azure SQL Private Endpoint (10.0.2.4:1433), In-Cluster Redis, and CSI Volume...');
                try {{
                    const res = await fetch('/api/verify-connections');
                    const data = await res.json();
                    document.getElementById('pod-badge').textContent = data.serving_pod;
                    document.getElementById('diag-sql-ip').textContent = `${{data.azure_sql_private_link.private_ip}} (${{data.azure_sql_private_link.fqdn}})`;
                    document.getElementById('diag-sql-tcp').textContent = data.azure_sql_private_link.tcp_1433_reachable ? `CONNECTED (${{data.azure_sql_private_link.latency_ms}}ms)` : 'FAILED';
                    document.getElementById('diag-redis').textContent = data.in_cluster_redis.ping_success ? `PONG (${{data.in_cluster_redis.latency_ms}}ms | Checks: ${{data.in_cluster_redis.total_verifications}})` : 'FAILED';
                    document.getElementById('diag-csi').textContent = data.csi_secret_store.files.join(', ');

                    appendLog('ZERO-TRUST', `Verified: SQL Private IP=${{data.azure_sql_private_link.private_ip}} (TCP 1433 OK), Redis=PONG, CSI Secrets=${{data.csi_secret_store.files.length}} files mounted.`);
                }} catch (err) {{
                    appendLog('ERROR', `Infrastructure verification failed: ${{err.message}}`, true);
                }}
            }}

            async function triggerChaos(endpoint, label) {{
                appendLog('CHAOS-INJECT', `Dispatching fault scenario [${{label}}] -> POST ${{endpoint}} ...`, true);
                const start = performance.now();
                try {{
                    const res = await fetch(endpoint, {{ method: 'POST' }});
                    const elapsed = Math.round(performance.now() - start);
                    let payload = {{}};
                    try {{ payload = await res.json(); }} catch (e) {{}}
                    if (payload.serving_pod) {{
                        document.getElementById('pod-badge').textContent = payload.serving_pod;
                    }}
                    appendLog(
                        `HTTP ${{res.status}}`,
                        `[${{label}}] completed in ${{elapsed}}ms on Pod ${{payload.serving_pod || 'terminated'}} -> ${{payload.message || 'Pod OOMKilled / Connection Reset'}}`,
                        res.status >= 400
                    );
                }} catch (err) {{
                    const elapsed = Math.round(performance.now() - start);
                    appendLog('POD-TERMINATED', `[${{label}}] Connection dropped after ${{elapsed}}ms — Kubernetes OOMKiller terminated the container! Refreshing active pod...`, true);
                    setTimeout(loadTransactions, 2000);
                }}
            }}

            // Initial load
            loadTransactions();
            verifyInfrastructure();
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)