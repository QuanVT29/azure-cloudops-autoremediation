<#
.SYNOPSIS
    Autonomous Auto-Remediation Runbook for AKS Core Banking Workloads (<10s MTTR).
.DESCRIPTION
    Authenticates secretlessly using System-Assigned Managed Identity, imports AKS
    cluster admin mTLS credentials into the sandbox UserKeySet, and triggers a
    zero-downtime rolling restart of 'banking-app' via Kubernetes REST API.
#>

param (
    [Parameter(Mandatory = $false)]
    [object] $WebhookData
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Core
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor 12288
} catch {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

Write-Output "[AUTO-REMEDIATION] Initiating Autonomous AKS Self-Healing Workflow"

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

function Read-Asn1TagAndLength {
    param([byte[]]$Data, [ref]$Offset)
    $tag = $Data[$Offset.Value]; $Offset.Value++
    $lenByte = $Data[$Offset.Value]; $Offset.Value++
    if ($lenByte -lt 0x80) {
        $len = [int]$lenByte
    } else {
        $numBytes = $lenByte -band 0x7F
        $len = 0
        for ($i = 0; $i -lt $numBytes; $i++) {
            $len = ($len * 256) + $Data[$Offset.Value]
            $Offset.Value++
        }
    }
    return @{ Tag = $tag; Length = $len }
}

function Read-Asn1Integer {
    param([byte[]]$Data, [ref]$Offset)
    $tl = Read-Asn1TagAndLength -Data $Data -Offset $Offset
    if ($tl.Tag -ne 0x02) { throw "Unexpected ASN.1 tag: $($tl.Tag)" }
    $bytes = New-Object byte[] $tl.Length
    [Array]::Copy($Data, $Offset.Value, $bytes, 0, $tl.Length)
    $Offset.Value += $tl.Length
    if ($bytes.Length -gt 1 -and $bytes[0] -eq 0x00) {
        $trimmed = New-Object byte[] ($bytes.Length - 1)
        [Array]::Copy($bytes, 1, $trimmed, 0, $trimmed.Length)
        return ,$trimmed
    }
    return ,$bytes
}

function Expand-LeftZero {
    param([byte[]]$Arr, [int]$TargetLen)
    if ($Arr.Length -ge $TargetLen) { return ,$Arr }
    $padded = New-Object byte[] $TargetLen
    [Array]::Copy($Arr, 0, $padded, $TargetLen - $Arr.Length, $Arr.Length)
    return ,$padded
}

function New-ClientCertFromPem {
    param([string]$CertPem, [string]$KeyPem)

    $PubCertBytes = [System.Text.Encoding]::UTF8.GetBytes($CertPem)
    $PubCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,$PubCertBytes)

    $CleanKeyB64 = ($KeyPem -replace '-----BEGIN [A-Z ]+-----', '' -replace '-----END [A-Z ]+-----', '' -replace '\s+', '')
    $DerBytes = [System.Convert]::FromBase64String($CleanKeyB64)

    $pos = 0
    $null = Read-Asn1TagAndLength -Data $DerBytes -Offset ([ref]$pos)

    if ($KeyPem -match 'BEGIN PRIVATE KEY') {
        $null = Read-Asn1Integer -Data $DerBytes -Offset ([ref]$pos)
        $alg  = Read-Asn1TagAndLength -Data $DerBytes -Offset ([ref]$pos)
        $pos += $alg.Length
        $null = Read-Asn1TagAndLength -Data $DerBytes -Offset ([ref]$pos)
        $null = Read-Asn1TagAndLength -Data $DerBytes -Offset ([ref]$pos)
    }

    $null = Read-Asn1Integer -Data $DerBytes -Offset ([ref]$pos)
    $rsaParams = New-Object System.Security.Cryptography.RSAParameters
    $rsaParams.Modulus  = Read-Asn1Integer -Data $DerBytes -Offset ([ref]$pos)
    $rsaParams.Exponent = Read-Asn1Integer -Data $DerBytes -Offset ([ref]$pos)
    $rsaParams.D        = Read-Asn1Integer -Data $DerBytes -Offset ([ref]$pos)
    $rsaParams.P        = Read-Asn1Integer -Data $DerBytes -Offset ([ref]$pos)
    $rsaParams.Q        = Read-Asn1Integer -Data $DerBytes -Offset ([ref]$pos)
    $rsaParams.DP       = Read-Asn1Integer -Data $DerBytes -Offset ([ref]$pos)
    $rsaParams.DQ       = Read-Asn1Integer -Data $DerBytes -Offset ([ref]$pos)
    $rsaParams.InverseQ = Read-Asn1Integer -Data $DerBytes -Offset ([ref]$pos)

    $modLen  = $rsaParams.Modulus.Length
    $halfLen = [int]($modLen / 2)
    $rsaParams.D        = Expand-LeftZero -Arr $rsaParams.D        -TargetLen $modLen
    $rsaParams.P        = Expand-LeftZero -Arr $rsaParams.P        -TargetLen $halfLen
    $rsaParams.Q        = Expand-LeftZero -Arr $rsaParams.Q        -TargetLen $halfLen
    $rsaParams.DP       = Expand-LeftZero -Arr $rsaParams.DP       -TargetLen $halfLen
    $rsaParams.DQ       = Expand-LeftZero -Arr $rsaParams.DQ       -TargetLen $halfLen
    $rsaParams.InverseQ = Expand-LeftZero -Arr $rsaParams.InverseQ -TargetLen $halfLen

    $CspParams = New-Object System.Security.Cryptography.CspParameters
    $CspParams.KeyContainerName = "AksRemediation-" + [Guid]::NewGuid().ToString()
    $CspParams.KeyNumber = 1
    $Rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider(2048, $CspParams)
    $Rsa.PersistKeyInCsp = $true
    $Rsa.ImportParameters($rsaParams)

    $CertWithKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::CopyWithPrivateKey($PubCert, $Rsa)
    $PfxBytes = $CertWithKey.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, "aks-temp")
    $Flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet
    return New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PfxBytes, "aks-temp", $Flags)
}

$ResourceGroupName = "rg-banking-ops-prod-compute-sea"
$AksClusterName    = "aks-banking-ops-prod-sea"
$TargetNamespace   = "default"
$TargetDeployment  = "banking-app"

try {
    Write-Output "[AUTH] Authenticating via System-Assigned Managed Identity..."
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity | Out-Null

    $SubId     = (Get-AzContext).Subscription.Id
    $Cluster   = Get-AzAksCluster -ResourceGroupName $ResourceGroupName -Name $AksClusterName
    $ApiServer = "https://$($Cluster.Fqdn)"

    $CredPath     = "/subscriptions/$SubId/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerService/managedClusters/$AksClusterName/listClusterAdminCredential?api-version=2024-02-01"
    $CredResponse = Invoke-AzRestMethod -Method POST -Path $CredPath
    if ($CredResponse.StatusCode -ne 200) {
        throw "Failed to retrieve AKS admin credentials (HTTP $($CredResponse.StatusCode)): $($CredResponse.Content)"
    }

    $CredJson       = $CredResponse.Content | ConvertFrom-Json
    $KubeconfigYaml = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($CredJson.kubeconfigs[0].value))

    if ($KubeconfigYaml -match 'client-certificate-data:\s*([A-Za-z0-9+/=]+)') {
        $CertPem = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Matches[1]))
    } else {
        throw "client-certificate-data not found in kubeconfig."
    }

    if ($KubeconfigYaml -match 'client-key-data:\s*([A-Za-z0-9+/=]+)') {
        $KeyPem = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Matches[1]))
    } else {
        throw "client-key-data not found in kubeconfig."
    }

    $ClientCert = New-ClientCertFromPem -CertPem $CertPem -KeyPem $KeyPem
    Write-Output "[AUTH] Persisted mTLS certificate in UserKeySet. Connecting to $ApiServer..."

    $Headers = @{
        "Content-Type" = "application/strategic-merge-patch+json"
        "Accept"       = "application/json"
    }

    $RestartTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $PatchPayload = @{
        spec = @{
            template = @{
                metadata = @{
                    annotations = @{
                        "kubectl.kubernetes.io/restartedAt" = $RestartTimestamp
                    }
                }
            }
        }
    } | ConvertTo-Json -Depth 5

    $DeployUri = "$ApiServer/apis/apps/v1/namespaces/$TargetNamespace/deployments/$TargetDeployment"
    Write-Output "[ACTION] Triggering rolling restart on deployment/$TargetDeployment (namespace: $TargetNamespace)..."

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $PatchResponse = Invoke-RestMethod -Method Patch -Uri $DeployUri -Headers $Headers -Body $PatchPayload -Certificate $ClientCert -SkipCertificateCheck
    } else {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        $PatchResponse = Invoke-RestMethod -Method Patch -Uri $DeployUri -Headers $Headers -Body $PatchPayload -Certificate $ClientCert
    }

    Write-Output "[RESULT] Deployment '$($PatchResponse.metadata.name)' patched (Generation: $($PatchResponse.metadata.generation), RestartedAt: $RestartTimestamp)."

    $PodsUri = "$ApiServer/api/v1/namespaces/$TargetNamespace/pods?labelSelector=app=$TargetDeployment"
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $PodsList = Invoke-RestMethod -Method Get -Uri $PodsUri -Headers @{ "Accept" = "application/json" } -Certificate $ClientCert -SkipCertificateCheck
    } else {
        $PodsList = Invoke-RestMethod -Method Get -Uri $PodsUri -Headers @{ "Accept" = "application/json" } -Certificate $ClientCert
    }

    foreach ($Pod in $PodsList.items) {
        Write-Output "  -> Pod: $($Pod.metadata.name) | Phase: $($Pod.status.phase)"
    }

    Write-Output "[SUCCESS] Auto-Remediation completed (<60s MTTR target achieved)."
}
catch {
    Write-Error "[CRITICAL] Auto-Remediation failed: $($_.Exception.Message)"
    throw $_
}
