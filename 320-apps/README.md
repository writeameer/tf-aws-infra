# 320-apps - Application Deployments

This folder contains Kubernetes application manifests and deployments.

## Structure
- **nginx-alb.yaml** - Sample nginx application with Application Load Balancer ingress
- Future: Additional sample applications and deployment patterns

## Prerequisites
- EKS cluster deployed (300-eks)
- AWS Load Balancer Controller addon installed (310-eks-addons)

## Usage

Deploy the nginx demo application:
```bash
kubectl apply -f nginx-alb.yaml
```

Check deployment status:
```bash
kubectl get deployments
kubectl get services  
kubectl get ingress
kubectl get pods
```

## Clean Architecture
- **300-eks**: Core EKS cluster infrastructure
- **310-eks-addons**: Kubernetes addons (AWS Load Balancer Controller, etc.)
- **320-apps**: Application deployments and manifests