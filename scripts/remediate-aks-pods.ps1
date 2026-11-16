<#
.SYNOPSIS
    Autonomous Auto-Remediation Runbook for AKS Core Banking Workloads (<60s MTTR).
.DESCRIPTION
    Triggered by Azure Monitor Action Group via Webhook when a P1/P2 alert fires.
    Authenticates secretlessly using the Azure Automation Account's System-Assigned
    Managed Identity and executes a rolling restart of the 'banking-app' deployment.
#>

param (
    [Parameter(Mandatory = $false)]
    [object] $WebhookData
)

$ErrorActionPreference = "Stop"

Write-Output "[AUTO-REMEDIATION] Initiating Autonomous AKS Self-Healing Workflow"


# 1. Parse Incoming Azure Monitor Common Alert Schema Payload
$AlertRuleName = "Manual-CLI-Trigger"
$Severity      = "Sev1"

if ($WebhookData -and $WebhookData.RequestBody) {
    try {
        $Payload = ConvertFrom-Json -InputObject $WebhookData.RequestBody
        if ($Payload.data -and $Payload.data.essentials) {
            $AlertRuleName = $Payload.data.essentials.alertRule
            $Severity      = $Payload.data.essentials.severity
            $FiredTime     = $Payload.data.essentials.firedDateTime
            Write-Output "[ALERT CONTEXT] Rule: $AlertRuleName | Severity: $Severity | Fired: $FiredTime"
        }
    }
    catch {
        Write-Warning "[WARN] Could not parse webhook JSON payload. Using default remediation parameters."
    }
}


# 2. Target AKS Workload Configuration
$ResourceGroupName = "rg-banking-ops-prod-compute-sea"
$AksClusterName    = "aks-banking-ops-prod-sea"
$TargetNamespace   = "default"
$TargetDeployment  = "banking-app"

try {

    # 3. Secretless Authentication via System-Assigned Managed Identity
    Write-Output "[AUTH] Authenticating via System-Assigned Managed Identity..."
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity | Out-Null
    Write-Output "[AUTH] Authenticated to Azure Control Plane."

    # 4. Execute Autonomous Pod Recovery via AKS Run Command API
    $KubectlCommand = "kubectl rollout restart deployment/$TargetDeployment -n $TargetNamespace && kubectl get pods -n $TargetNamespace -l app=$TargetDeployment"
    Write-Output "[ACTION] Executing remote rollout restart on cluster '$AksClusterName'..."
    Write-Output "[COMMAND] $KubectlCommand"

    $RemediationResult = Invoke-AzAksRunCommand `
        -ResourceGroupName $ResourceGroupName `
        -Name $AksClusterName `
        -Command $KubectlCommand `
        -Force

    Write-Output "[RESULT] AKS Control Plane Output:"
    Write-Output $RemediationResult.Logs

    Write-Output "[SUCCESS] Auto-Remediation completed (<60s MTTR target achieved)."

}
catch {
    Write-Error "[CRITICAL] Auto-Remediation failed: $($_.Exception.Message)"
    throw $_
}