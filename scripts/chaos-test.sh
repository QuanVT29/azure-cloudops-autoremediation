#!/usr/bin/env bash
# Purpose: Fault-injection CLI testing toolkit for AKS Core Banking Platform
# Usage:   ./scripts/chaos-test.sh [500|latency|oom|verify] [count]
set -euo pipefail

SCENARIO="${1:-500}"
COUNT="${2:-5}"

echo "[INFO] Resolving External IP for 'banking-app-service' on AKS..."
APP_IP=$(kubectl get svc banking-app-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

if [[ -z "$APP_IP" ]]; then
  echo "[ERROR] Could not retrieve LoadBalancer External IP. Ensure AKS is running."
  exit 1
fi

BASE_URL="http://${APP_IP}"
echo "[TARGET] Core Banking Endpoint: ${BASE_URL}"
echo "------------------------------------------------------------------"

case "$SCENARIO" in
  500)
    echo "[CHAOS] Injecting ${COUNT} bursts of P1 HTTP 500 Critical Outage..."
    for ((i=1; i<=COUNT; i++)); do
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/fault/500")
      echo "  -> Burst #${i}: HTTP ${HTTP_CODE} (CHAOS_EVENT_P1 emitted to Container Insights)"
      sleep 1
    done
    ;;
  latency)
    echo "[CHAOS] Injecting ${COUNT} requests of P2 High Latency (>3500ms SLA Breach)..."
    for ((i=1; i<=COUNT; i++)); do
      TIME_TOTAL=$(curl -s -o /dev/null -w "%{time_total}" -X POST "${BASE_URL}/api/fault/slow-dependency")
      echo "  -> Request #${i}: Completed in ${TIME_TOTAL}s (CHAOS_EVENT_P2 emitted)"
    done
    ;;
  oom)
    echo "[CHAOS] Triggering OOM Memory Exhaustion (CrashLoopBackOff simulation)..."
    curl -s -X POST "${BASE_URL}/api/fault/oom" || true
    echo ""
    echo "[WATCH] Current Pod status after memory spike:"
    kubectl get pods -l app=banking-app
    ;;
  verify)
    echo "[VERIFY] Probing Zero-Trust Private Link & CSI Secrets..."
    curl -s "${BASE_URL}/api/verify-connections" | python3 -m json.tool
    ;;
  *)
    echo "Usage: $0 [500|latency|oom|verify] [count]"
    exit 1
    ;;
esac

echo "[DONE] Chaos injection complete. Monitor Azure Alerts & Runbook jobs."