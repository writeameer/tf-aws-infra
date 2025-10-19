
function Restart-Kubelet() 
{
    $instances = (Get-EC2Instance).Instances.InstanceId

    $instances | ForEach-Object {
        Write-Host "Restarting kubelet on instance $_"
        aws ssm send-command `
        --document-name "AWS-RunShellScript" `
        --instance-ids $_ `
        --parameters commands='["sudo systemctl restart kubelet"]' `
        --comment "Restart kubelet on this EKS node" | Out-Null
    }
}

Restart-Kubelet
