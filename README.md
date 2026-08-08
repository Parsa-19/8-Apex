# General Idea
This is a basic k8s cluster project setup which is a design of a **production k8s platform** that is going to help me build a whole infrastructure from the scratch and improve in my DevOps skills.

although for now I've planned to implement it localy on VirtualBox machines but It'll grow.

> [!NOTE]
> This repo contains 2 branches named `tuf` and `sherkat` which is the same basic idea implemented on two device environment labs. for example `tuf` is a branch which I decided to use to develop the project on my laptop device and `sherkat` is another branch dedicated for the PC device in sherkat. 

# project 8-Apex
The project's name is **8-Apex** means k8s at it's highst level of response and functionalities.

8-Apex is not just about k8s cluster but a whole ready platform to host multiple production applicatons with the implementations of automated deployment and tools to maintain and monitor your applicatoins; for example it consists of:
 - loggin and monitroing stacks
 - prepared container images
 - CI/CD piplines and automated deployments
 - persistant data storage solutions
 - backups
 - high availabel cluster control planes
 - application LoadBalancer


### Structure
This is a basic demonstration of cluster schema.<br>
It contains:
 * 3 load balanced Control-planes
 * 2 Worker-nodes
 * 1 applicatin level load balancer for network traffic entry point
```
                  kubectl
                     |
               api-server LB
                     |
   ┌─────────────────┼─────────────────┐
   |                 |                 |
  CP-1              CP-2              CP-2
(api-server)      (api-server)      (api-server)
   │                 │                 |
   └─────────────────┼─────────────────┘
                     |    
        ┌────────────┴────────────┐
        |                         |
        |                         |   
      Node1                     Node2
      (pods)                    (pods)
        |                         |   
        |                         |          CLUSTER
-----------------------------------------------------
        |                         |          INTERNET
        |                         |
        └────────────┬────────────┘
                     |
               Application-LB
                     |
                     |
                  Traffic
```

### VM settings
Each VM is Rocky-10.2 minimal.<br>
there is two network interface for each of them:
  - *enp0s3* - a NAT Network interface (just for tests and internet accessibility)
  - *enp0s8* - a host-only interface specified as the **node's main IP address**. 

### Cluster Details And Tools List
- cluster is created using **kubeadm**
- CRI is **containerd**
- CNI is **Cilium**
- **Helm** as package manager
- **HeadLamp** as visual dashboard
- seprated **namespaces** for each environments:
    * kube-system
    * production
    * staging
    * monitoring
    * ingress
    * database
    * logging
    * ci-cd
    * tools (internal utilities like admin tools, dashboard, MinIO...)
- deployed apps each with **(Deployments, Service, ConfigMap, Secret, PersistentVolumeClaim)**:
    * Laravel API
    * Django API
    * React frontend
    * Redis
    * RabbitMQ
    * MySQL
- Ingress:
    * `api.example.local`
    * `dashboard.example.local`
    * `django.example.local`
    * `grafana.example.local`
- persistent Storage:
    * MySQL
    * PostgreSQL
    * Redis persistence
- Monitoring stack with **Prometheus & Grafana**
- **ELK** Logging stack 
- GitOps / CI-CD
- Autoscale
- RBAC, Secrets
- Velero or etcd snapshots for backup


# Projects Phases
This is a brief explantion and more a presentaion of how the project is shaped and planned phase by phase. The exact implementaion steps are explained in docs.

## Phase 1 - Infrastructure 
### VM specification and resource allociatons 
```
┌─────────┬──────────────────────────┬────────────────────┬────────────────────────────┬──────┬───────┬─────────┐
│ VM Name │ Role                     │ NAT (enp0s3)       │ Private (enp0s8)           │ vCPU │ RAM   │ Storage │
├─────────┼──────────────────────────┼────────────────────┼────────────────────────────┼──────┼───────┼─────────┤
│ CP-1    │ Kubernetes Control Plane │ 10.0.2.18          │ 192.168.55.118             │ 2    │ 2 GB  │ 10 GB   │
│ CP-2    │ Kubernetes Control Plane │ 10.0.2.19          │ 192.168.55.119             │ 2    │ 2 GB  │ 10 GB   │
│ CP-3    │ Kubernetes Control Plane │ 10.0.2.20          │ 192.168.55.120             │ 2    │ 2 GB  │ 10 GB   │
│ Node-1  │ Kubernetes Worker        │ 10.0.2.21          │ 192.168.55.121             │ 2    │ 5 GB  │ 25 GB   │
│ Node-2  │ Kubernetes Worker        │ 10.0.2.22          │ 192.168.55.122             │ 2    │ 5 GB  │ 25 GB   │
│ App-LB  │ External Load Balancer   │ 10.0.2.23          │ 192.168.55.123             │ 1    │ 1 GB  │ 10 GB   │
├─────────┼──────────────────────────┼────────────────────┼────────────────────────────┼──────┼───────┼─────────┤
│ Total   │ 6 Virtual Machines       │                    │                            │ 11   │ 17 GB │ 88 GB   │
└─────────┴──────────────────────────┴────────────────────┴────────────────────────────┴──────┴───────┴─────────┘
```
### Network Configuration
```
┌─────────────────────────────┬─────────────────┬────────────────────────────────────────────────────────────────────────────┬───────────────┐
│ Network                     │ CIDR            │ Purpose                                                                    │ Connected VMs │
├─────────────────────────────┼─────────────────┼────────────────────────────────────────────────────────────────────────────┼───────────────┤
│ NAT Network (enp0s3)        │ 10.0.2.0/24     │ Internet access, package installation, external connectivity               │ All           │
│ Private Cluster (enp0s8)    │ 192.168.55.0/24 │ Kubernetes communication, node networking, services, load balancer backend │ All           │
└─────────────────────────────┴─────────────────┴────────────────────────────────────────────────────────────────────────────┴───────────────┘
```
### Cluster Composition
```
┌─────────────────────────────┬──────────┬─────────────────────────────────────────────────────────────┐
│ Component                   │ Quantity │ Description                                                 │
├─────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────┤
│ Control Plane Nodes         │ 3        │ High-availability Kubernetes control plane                  │
│ Worker Nodes                │ 2        │ Hosts application workloads and platform services           │
│ External Load Balancer VM   │ 1        │ Routes external traffic to the Kubernetes Ingress Controller│
├─────────────────────────────┼──────────┼─────────────────────────────────────────────────────────────┤
│ Total Virtual Machines      │ 6        │ Complete Kubernetes infrastructure                          │
└─────────────────────────────┴──────────┴─────────────────────────────────────────────────────────────┘
```
### Tpology/Schema
```
                                     Cluster Administration
                                            (kubectl)
                                                │
                                                │  HTTPS :6443
                                                ▼
                                   ┌────────────────────────┐
                                   │ Kubernetes API LB      │
                                   │ (HAProxy / NGINX)      │
                                   └────────────┬───────────┘
                                                │
                    ┌───────────────────────────┼───────────────────────────┐
                    │                           │                           │
            ┌───────▼────────┐          ┌───────▼────────┐          ┌───────▼────────┐
            │ CP-1           │          │ CP-2           │          │ CP-3           │
            │ Control Plane  │          │ Control Plane  │          │ Control Plane  │
            │ API Server     │          │ API Server     │          │ API Server     │
            │ Scheduler      │          │ Scheduler      │          │ Scheduler      │
            │ Controller Mgr │          │ Controller Mgr │          │ Controller Mgr │
            │ etcd Member    │◄────────►│ etcd Member    │◄────────►│ etcd Member    │
            └───────┬────────┘          └───────┬────────┘          └───────┬────────┘
                    │                           │                           │
                    └─────────────── Cluster Control Plane ─────────────────┘
                                                │
                              ──────────────────┼──────────────────
                                                │
                 ┌──────────────────────────────┴───────────────────────────────┐
                 │                                                              │
        ┌────────▼─────────┐                                           ┌────────▼─────────┐
        │ Worker Node-1    │                                           │ Worker Node-2    │
        │ kubelet          │                                           │ kubelet          │
        │ kube-proxy       │                                           │ kube-proxy       │
        │ Container Runtime│                                           │ Container Runtime│
        │ Application Pods │                                           │ Application Pods │
        │ Monitoring Pods  │                                           │ Logging Pods     │
        └────────┬─────────┘                                           └────────┬─────────┘
                 │                                                              │
                 └─────────────────────── Cluster Services ─────────────────────┘
                                                │
       ═════════════════════════════════════════════════════════════════════════════════════
                                  Kubernetes Cluster Boundary
       ═════════════════════════════════════════════════════════════════════════════════════
                                                │
                                        Ingress Controller
                                    (NGINX / Traefik Ingress)
                                                │
                                                │
                                     Application Load Balancer
                                       (HAProxy / NGINX VM)
                                                │
                                            HTTP/HTTPS
                                                │
                                             Internet
                                                │
                                             Clients
```
> [!NOTE]
> for ha control planes, etc needs odd number of control plane nodes.



namespace design

database design

external LB

CI/CD pipeline with gitOps
    container registry (docker hub or gitlab)



## Phase 2 - Install k8s

## Phase 3 - Multi-Namespace Environment

## Phase 4 - Deploy Applications

## Phase 5 - Ingress

## Phase 6 - Persistent Storage

## Phase 7 - Monitoring Stack

## Phase 8 - Logging

## Phase 9 - GitOps / CI-CD

## Phase 10 - Autoscaling

## Phase 11 - Security

## Phase 8 - Backup

## Phase 8 - Disaster Recovery

## Phase 8 - Documentation
