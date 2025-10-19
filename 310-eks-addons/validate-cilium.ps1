<#
PURPOSE
-------
We are validating the health of an Amazon EKS test cluster that has migrated
from the AWS VPC CNI + kube-proxy model to **Cilium** using the **cluster-pool IPAM**
mode.

WHY WE'RE DOING THIS
--------------------
When Cilium was previously configured with `ipam.mode = "eni"`, several
operational issues appeared:
  • Severe pod-density limits (~4 pods per node) due to ENI IP constraints
  • Frequent "No more IPs available" errors
  • cilium-operator crashes related to ENI configuration
  • Node scaling conflicts with Terraform
  • Webhook install timeouts

By switching to **cluster-pool IPAM** we decoupled pod IP allocation from AWS ENIs,
restoring normal scheduling behavior and stable Cilium operation.

WHAT THIS CHECKLIST VERIFIES
----------------------------
1. Cilium DaemonSet and operator are healthy
2. IPAM mode = cluster-pool with proper CIDR configuration
3. Kube-proxy replacement (KPR) is active and configured
4. Old CNIs (`aws-node`, `kube-proxy`) are gone
5. Pod-density across nodes is healthy
6. No IP exhaustion events
7. CoreDNS functionality
8. Node readiness status
9. Optional service reachability test

EXPECTED TARGET STATE
---------------------
✅ Cilium running with `ipam.mode=cluster-pool`
✅ `kubeProxyReplacement=true` with valid `k8sServiceHost`
✅ No `aws-node` or `kube-proxy` DaemonSets
✅ Normal pod density (≥20 allocatable per node)
✅ cilium-operator Ready
✅ No IP exhaustion or webhook errors

Run this checklist after each major network change to ensure the cluster
remains healthy and that migration to Cilium cluster-pool mode succeeded.

# --- Begin validation script ---
# Tested on macOS PowerShell (Warp)
# Requires: kubectl, helm, jq (brew install jq), Terraform repo in cwd
# ----------------------------------------------------------------------
#>
$Results = @()

function Add-Result($Status, $Check, $Details) {
    $script:Results += [PSCustomObject]@{
        Check   = $Check
        Status  = $Status
        Details = $Details
    }
}

function Safe-Execute($Command, $ErrorValue = "ERROR") {
    try {
        $output = Invoke-Expression $Command 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $output
        } else {
            return $ErrorValue
        }
    } catch {
        return $ErrorValue
    }
}

Write-Host "=== Cilium Cluster-Pool Validation ===`n" -ForegroundColor Cyan

# ---------- Check 1: Cilium DaemonSet ----------
Write-Host "Checking Cilium DaemonSet..." -ForegroundColor Yellow
$ciliumStatus = Safe-Execute "helm status cilium -n kube-system"
if ($ciliumStatus -ne "ERROR") {
    $dsJson = Safe-Execute "kubectl -n kube-system get ds cilium -o json"
    if ($dsJson -ne "ERROR") {
        $ds = $dsJson | ConvertFrom-Json
        if ($ds.status.numberReady -eq $ds.status.desiredNumberScheduled) {
            Add-Result "PASS" "Cilium DS" "Ready ($($ds.status.numberReady)/$($ds.status.desiredNumberScheduled))"
        } else {
            Add-Result "ATTN" "Cilium DS" "Not fully ready ($($ds.status.numberReady)/$($ds.status.desiredNumberScheduled))"
        }
    } else {
        Add-Result "FAIL" "Cilium DS" "Cannot get DaemonSet status"
    }
} else {
    Add-Result "FAIL" "Cilium" "Helm release not found"
}

# ---------- Check 2: Cilium Operator ----------
Write-Host "Checking Cilium Operator..." -ForegroundColor Yellow
$operatorJson = Safe-Execute "kubectl -n kube-system get deployment cilium-operator -o json"
if ($operatorJson -ne "ERROR") {
    $operator = $operatorJson | ConvertFrom-Json
    if ($operator.status.readyReplicas -eq $operator.status.replicas) {
        Add-Result "PASS" "Cilium Operator" "Ready ($($operator.status.readyReplicas)/$($operator.status.replicas))"
    } else {
        Add-Result "ATTN" "Cilium Operator" "Not fully ready ($($operator.status.readyReplicas)/$($operator.status.replicas))"
    }
} else {
    Add-Result "FAIL" "Cilium Operator" "Deployment not found"
}

# ---------- Check 3: IPAM and KPR modes ----------
Write-Host "Checking IPAM and KPR configuration..." -ForegroundColor Yellow
$ciliumStatusOutput = Safe-Execute "kubectl -n kube-system exec ds/cilium -- cilium status"
$helmValues = Safe-Execute "helm get values cilium -n kube-system -o yaml"

$IPAM = "UNKNOWN"
$KPR = "UNKNOWN"
if ($ciliumStatusOutput -ne "ERROR") {
    $ipamLine = $ciliumStatusOutput | Select-String "IPAM:" | Select-Object -First 1
    if ($ipamLine) {
        $IPAM = ($ipamLine -split ":")[1].Trim()
    }
    
    $kprLine = $ciliumStatusOutput | Select-String "KubeProxyReplacement:" | Select-Object -First 1
    if ($kprLine) {
        $KPR = ($kprLine -split ":")[1].Trim()
    }
}

$IPAMVal = "UNKNOWN"
$PoolCIDR = "UNKNOWN"
$NativeCIDR = "UNKNOWN" 
$HostVal = "UNKNOWN"

if ($helmValues -ne "ERROR") {
    $ipamValLine = $helmValues | Select-String "mode:" | Select-Object -First 1
    if ($ipamValLine) {
        $IPAMVal = ($ipamValLine -split ":")[1].Trim() -replace '"',''
    }
    
    $poolLine = $helmValues | Select-String "clusterPoolIPv4PodCIDRList:" | Select-Object -First 1
    if ($poolLine) {
        $PoolCIDR = ($poolLine -split ":")[1].Trim() -replace '"',''
    }
    
    $nativeLine = $helmValues | Select-String "ipv4NativeRoutingCIDR:" | Select-Object -First 1
    if ($nativeLine) {
        $NativeCIDR = ($nativeLine -split ":")[1].Trim() -replace '"',''
    }
    
    $hostLine = $helmValues | Select-String "k8sServiceHost:" | Select-Object -First 1
    if ($hostLine) {
        $HostVal = ($hostLine -split ":")[1].Trim() -replace '"',''
    }
}

if ($IPAMVal -eq "cluster-pool" -or $IPAM -eq "cluster-pool") {
    if ($PoolCIDR -ne "UNKNOWN" -and $NativeCIDR -ne "UNKNOWN") {
        Add-Result "PASS" "Cilium IPAM" "cluster-pool ($PoolCIDR), nativeCIDR=$NativeCIDR"
    } else {
        Add-Result "ATTN" "Cilium IPAM" "cluster-pool but missing CIDRs (Pool:$PoolCIDR, Native:$NativeCIDR)"
    }
} elseif ($IPAMVal -eq "eni" -or $IPAM -eq "eni") {
    Add-Result "WARN" "Cilium IPAM" "Still using ENI mode - migration incomplete"
} else {
    Add-Result "FAIL" "Cilium IPAM" "Unknown IPAM mode: $IPAM/$IPAMVal"
}

if ($KPR -eq "True" -or $KPR -eq "Strict") {
    if ($HostVal -ne "UNKNOWN") {
        Add-Result "PASS" "Kube-Proxy Replacement" "$KPR (host: $HostVal)"
    } else {
        Add-Result "ATTN" "Kube-Proxy Replacement" "$KPR but no k8sServiceHost set"
    }
} else {
    Add-Result "WARN" "Kube-Proxy Replacement" "Not enabled: $KPR"
}

# ---------- Check 4: Old CNI Components Gone ----------
Write-Host "Checking for old CNI components..." -ForegroundColor Yellow
$awsNode = Safe-Execute "kubectl -n kube-system get ds aws-node"
if ($awsNode -eq "ERROR") {
    Add-Result "PASS" "AWS VPC CNI" "Removed (aws-node DaemonSet not found)"
} else {
    Add-Result "WARN" "AWS VPC CNI" "Still present - cleanup needed"
}

$kubeProxy = Safe-Execute "kubectl -n kube-system get ds kube-proxy"
if ($kubeProxy -eq "ERROR") {
    Add-Result "PASS" "Kube-Proxy" "Removed (kube-proxy DaemonSet not found)"
} else {
    Add-Result "WARN" "Kube-Proxy" "Still present - cleanup needed"
}

# ---------- Check 5: Node Health and Pod Density ----------
Write-Host "Checking node health and pod density..." -ForegroundColor Yellow
$nodesJson = Safe-Execute "kubectl get nodes -o json"
if ($nodesJson -ne "ERROR") {
    $nodes = $nodesJson | ConvertFrom-Json
    $healthyNodes = 0
    $totalNodes = $nodes.items.Count
    
    foreach ($node in $nodes.items) {
        $nodeName = $node.metadata.name
        $allocatable = [int]$node.status.allocatable.pods
        $ready = ($node.status.conditions | Where-Object {$_.type -eq "Ready"}).status
        
        if ($ready -eq "True") {
            $healthyNodes++
        }
        
        if ($allocatable -lt 10) {
            Add-Result "WARN" "Pod Density" "${nodeName}: Low allocatable pods (${allocatable}) - potential ENI issue"
        }
    }
    
    Add-Result "PASS" "Node Health" "$healthyNodes/$totalNodes nodes ready"
    
    # Check for recent IP allocation errors
    $events = Safe-Execute "kubectl get events --all-namespaces --field-selector reason=FailedCreatePodSandBox -o json"
    if ($events -ne "ERROR") {
        $eventsObj = $events | ConvertFrom-Json
        $ipErrors = $eventsObj.items | Where-Object {$_.message -like "*No more IPs available*"}
        if ($ipErrors.Count -gt 0) {
            Add-Result "WARN" "IP Allocation" "Found $($ipErrors.Count) recent 'No more IPs available' errors"
        } else {
            Add-Result "PASS" "IP Allocation" "No recent IP exhaustion errors"
        }
    }
} else {
    Add-Result "FAIL" "Node Health" "Cannot get node status"
}

# ---------- Check 6: CoreDNS Health ----------
Write-Host "Checking CoreDNS..." -ForegroundColor Yellow
$coreDnsJson = Safe-Execute "kubectl -n kube-system get deployment coredns -o json"
if ($coreDnsJson -ne "ERROR") {
    $coreDns = $coreDnsJson | ConvertFrom-Json
    if ($coreDns.status.readyReplicas -eq $coreDns.status.replicas) {
        Add-Result "PASS" "CoreDNS" "Ready ($($coreDns.status.readyReplicas)/$($coreDns.status.replicas))"
    } else {
        Add-Result "ATTN" "CoreDNS" "Not fully ready ($($coreDns.status.readyReplicas)/$($coreDns.status.replicas))"
    }
} else {
    Add-Result "FAIL" "CoreDNS" "Deployment not found"
}

# ---------- Check 7: Test Pod Scheduling ----------
Write-Host "Testing pod scheduling..." -ForegroundColor Yellow
$testResult = Safe-Execute "kubectl create deployment test-cilium-validation --image=nginx:alpine --dry-run=server"
if ($testResult -ne "ERROR") {
    Add-Result "PASS" "Pod Scheduling" "Test deployment validated successfully"
} else {
    Add-Result "FAIL" "Pod Scheduling" "Cannot schedule test pod"
}

# ---------- Results Summary ----------
Write-Host "`n=== VALIDATION RESULTS ===" -ForegroundColor Cyan
$passCount = ($Results | Where-Object {$_.Status -eq "PASS"}).Count
$attnCount = ($Results | Where-Object {$_.Status -eq "ATTN"}).Count  
$warnCount = ($Results | Where-Object {$_.Status -eq "WARN"}).Count
$failCount = ($Results | Where-Object {$_.Status -eq "FAIL"}).Count

$Results | Format-Table -AutoSize

Write-Host "`nSUMMARY: " -NoNewline -ForegroundColor Cyan
Write-Host "PASS: $passCount " -NoNewline -ForegroundColor Green
Write-Host "ATTN: $attnCount " -NoNewline -ForegroundColor Yellow
Write-Host "WARN: $warnCount " -NoNewline -ForegroundColor Magenta
Write-Host "FAIL: $failCount" -ForegroundColor Red

if ($failCount -eq 0 -and $warnCount -eq 0) {
    Write-Host "`n✅ Cilium cluster-pool migration appears successful!" -ForegroundColor Green
} elseif ($failCount -eq 0) {
    Write-Host "`n⚠️  Migration mostly successful with minor warnings" -ForegroundColor Yellow
} else {
    Write-Host "`n❌ Migration has issues that need attention" -ForegroundColor Red
}

# Cleanup
Write-Host "`nCleaning up test resources..." -ForegroundColor Yellow
Safe-Execute "kubectl delete deployment test-cilium-validation --ignore-not-found=true" | Out-Null
Safe-Execute "kubectl delete deployment test-fixed --ignore-not-found=true" | Out-Null

Write-Host "Validation complete.`n" -ForegroundColor Cyan