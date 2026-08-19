# 8-Apex — Production-Like Kubernetes Platform

> A hands-on DevOps project for designing, deploying, and operating a production-inspired Kubernetes platform from scratch using Linux, kubeadm, containerd, Cilium, and open-source infrastructure tools.

---

## Overview

**8-Apex** is a personal DevOps project focused on building a production-like Kubernetes platform from the ground up.

The goal is not simply to create a Kubernetes cluster, but to build a reusable platform capable of hosting multiple applications while providing:

- High availability
- Application load balancing
- Persistent storage
- Monitoring and logging
- CI/CD and GitOps
- Automated scaling
- Backup and disaster recovery
- Security and access control

The project is currently being developed locally using VirtualBox VMs. The infrastructure is designed so that it can be extended to a larger or cloud-based environment later.

---

## Project Goals

The main goals of 8-Apex are to:

1. Build a highly available Kubernetes cluster using `kubeadm`.
2. Gain practical experience managing Kubernetes on Linux.
3. Deploy real-world applications rather than simple demonstration workloads.
4. Implement production-oriented infrastructure and platform services.
5. Automate application deployment through CI/CD and GitOps.
6. Implement monitoring, logging, storage, backups, and disaster recovery.
7. Document the architecture, implementation, troubleshooting, and lessons learned.

---

## Development Environments

This project is currently maintained across two local lab environments.

The branches:

- `tuf`
- `sherkat`

represent the same project architecture implemented on different physical machines.

The infrastructure-specific configuration may differ between environments, while the overall architecture and objectives remain the same.

---

# Architecture

The initial infrastructure consists of:

- **3 Kubernetes control-plane nodes**
- **2 Kubernetes worker nodes**
- **2 external load-balancer VMs**

This is a High Available k8s cluster which means it has 3 control-plane nodes ensuring there is no Singel Point of Failure or Control Plane Redundancy.

etcd architecture design is **stacked etcd topology** meaning that all etcd members are inside their related control plane node but connected to each other. 
> [!NOTE]
> for ha control planes, etcd needs odd number of control plane nodes to work efficient and be synced. if one CP goes down and its etcd loses data track, there is always two more etcd and it could be recovered.
```
                               Cluster Administration
                                      (kubectl)
                                          │
                                          │  HTTPS :6443
                                          ▼
                      ┌─────────────────────────────────────────┐
                      │ Kubernetes API Virtual IP (kube-vip)    │
                      │                                         │
                      │ VIP: 10.0.0.100:6443                    │
                      │                                         │
                      │ • Provides HA Virtual IP for Kubernetes │
                      │   API Server                            │
                      │ • kube-vip runs on all Control Planes   │
                      │ • One node is Active/Leader at a time   │
                      │ • VIP automatically moves if the leader │
                      │   fails                                 │
                      │ • No dedicated API load-balancer node   │
                      │   required                              │
                      └───────────────────┬─────────────────────┘
                                          │                          
                  ┌───────────────────────┼────────────────────────┐
                  │                       │                        │
                  ▼                       ▼                        ▼
         ┌────────────────┐       ┌────────────────┐       ┌────────────────┐
         │ CP-1           │       │ CP-2           │       │ CP-3           │
         │ Control Plane  │       │ Control Plane  │       │ Control Plane  │
         │                │       │                │       │                │
         │ kube-vip       │       │ kube-vip       │       │ kube-vip       │
         │ VIP:           │       │ VIP:           │       │ VIP:           │
         │ 10.0.0.100     │       │ 10.0.0.100     │       │ 10.0.0.100     │
         │ Active/Leader  │       │ Backup         │       │ Backup         │
         │                │       │                │       │                │
         │ API Server     │       │ API Server     │       │ API Server     │
         │ Scheduler      │       │ Scheduler      │       │ Scheduler      │
         │ Controller Mgr │       │ Controller Mgr │       │ Controller Mgr │
         │ etcd Member    │◄─────►│ etcd Member    │◄─────►│ etcd Member    │
         └───────┬────────┘       └───────┬────────┘       └───────┬────────┘
                 │                        │                        │
                 │                        │                        │
                 └──────────────── etcd Cluster (Raft) ────────────┘
                                          │
                                          │
                               Cluster Control Plane
                                          │
          ────────────────────────────────┼────────────────────────────────
                                          │
                      ┌───────────────────┴────────────────────┐
                      │                                        │
            ┌─────────▼──────────┐                   ┌─────────▼──────────┐
            │ Worker Node-1      │                   │ Worker Node-2      │
            │                    │                   │                    │
            │ kubelet            │                   │ kubelet            │
            │ kube-proxy         │                   │ kube-proxy         │
            │ Container Runtime  │                   │ Container Runtime  │
            │                    │                   │                    │
            │ Application Pods   │                   │ Application Pods   │
            │ Monitoring Pods    │                   │ Logging Pods       │
            └─────────┬──────────┘                   └─────────┬──────────┘
                      │                                        │
                      └──────────── Cluster Services ──────────┘
                                          │
 ═════════════════════════════════════════════════════════════════════════════════════
                            Kubernetes Cluster Boundary
 ═════════════════════════════════════════════════════════════════════════════════════
                                          │
                                Ingress Controllers
                              (NGINX / Traefik Ingress)
                                     ▲        ▲
                                     │        │
                ┌────────────────────┘        └────────────────────┐
                │                                                  │
       ┌────────▼────────┐                                ┌────────▼────────┐
       │ Application LB-1│                                │ Application LB-2│
       │ (HAProxy/NGINX) │                                │ (HAProxy/NGINX) │
       └────────┬────────┘                                └────────┬────────┘
                │                                                  │
                └─────────────────────────┬────────────────────────┘
                                          │
                                          ▲
                                          |
                                          |
                                     HTTP / HTTPS
                                          │
                                 Internet / WAN
                                          │
                                       Clients
```
there is **no dedicated Kubernetes API LB node** in this design. `kube-vip` runs directly on the control-plane nodes and provides the shared API VIP (`10.0.0.100`). The API traffic is therefore highly available across CP-1, CP-2 and CP-3 while etcd remains replicated across the three control planes.

there is also two external app `haproxy`/`nginx` loadbalancers which routes the traffic to worker nodes and application pods through `ingress controller`.

> [!TIP]
> check the detailed architecture diagram in [diagrams folder](https://github.com/Parsa-19/8-Apex/tree/tuf/diagrams) in root of repository.

---

# Infrastructure

## Virtual Machines/Resources

The current lab uses Rocky Linux minimal VMs for all the nodes running on VirtualBox.

| VM        | Role                     | NAT (enp0s3) | Private (enp0s8) |   vCPU |       RAM |    Storage |
| --------- | ------------------------ | -----------: | ---------------: | -----: | --------: | ---------: |
| CP-1      | Kubernetes Control Plane |    10.0.2.18 |   192.168.16.118 |      3 |      2 GB |      20 GB |
| CP-2      | Kubernetes Control Plane |    10.0.2.19 |   192.168.16.119 |      3 |      2 GB |      20 GB |
| CP-3      | Kubernetes Control Plane |    10.0.2.20 |   192.168.16.120 |      3 |      2 GB |      20 GB |
| Node-1    | Kubernetes Worker        |    10.0.2.21 |   192.168.16.121 |      3 |      4 GB |      25 GB |
| Node-2    | Kubernetes Worker        |    10.0.2.22 |   192.168.16.122 |      3 |      4 GB |      25 GB |
| LB-1      | External Load Balancer   |    10.0.2.23 |   192.168.16.123 |      1 |      1 GB |      20 GB |
| LB-2      | External Load Balancer   |    10.0.2.24 |   192.168.16.124 |      1 |      1 GB |      20 GB |

**Total:** 7 virtual machines, 15 vCPU, 15 GB RAM, 150 GB storage.

---

## Network

Each VM has two network interfaces:

### `enp0s3` — NAT Network

Used for:

- Internet access
- Package installation
- External connectivity

Network:

```text
10.0.2.0/24
```

### `enp0s8` — Private Cluster Network

Used as the primary cluster network for:

- Kubernetes node communication
- Cluster services
- Application traffic
- Load-balancer communication

Network:

```text
192.168.16.0/24
```

---

# Kubernetes Stack

The cluster is built using the following technologies:

| Component               | Technology              |
| ----------------------- | ----------------------- |
| Operating System        | Rocky Linux             |
| Kubernetes Installation | kubeadm                 |
| Container Runtime       | containerd              |
| CNI                     | Cilium                  |
| Package Manager         | Helm                    |
| Kubernetes Dashboard    | Headlamp                |
| Ingress                 | TBD                     |
| External Load Balancer  | HAProxy / NGINX         |
| Monitoring              | Prometheus + Grafana    |
| Logging                 | ELK                     |
| Backup                  | Velero / etcd snapshots |
| CI/CD                   | GitHub Actions          |
| GitOps                  | Planned                 |

---

# Namespace Design

The cluster will be logically separated into namespaces based on responsibility:

```text
kube-system
production
staging
monitoring
ingress
database
logging
ci-cd
tools
```

The `tools` namespace is intended for internal utilities such as administrative tools, dashboards, and MinIO.

This separation provides a cleaner organizational structure and makes it possible to apply resource limits, access policies, and security controls independently.

---

# Applications

The platform is intended to host multiple applications and supporting services.

### Applications

- Laravel API
- Django API
- React frontend

### Supporting Services

- Redis
- RabbitMQ
- MySQL

Applications will use Kubernetes resources such as:

- Deployments
- Services
- ConfigMaps
- Secrets
- PersistentVolumeClaims

The exact Kubernetes resources used by each application may vary depending on its requirements.

---

# Application Traffic

The planned application traffic flow is:

```text
Client
   │
   ▼
External Load Balancer
   │
   ▼
Ingress Controller
   │
   ├── api.example.local
   │        │
   │        ▼
   │     Laravel API
   │
   ├── django.example.local
   │        │
   │        ▼
   │     Django API
   │
   ├── dashboard.example.local
   │        │
   │        ▼
   │     Platform Dashboard
   │
   └── grafana.example.local
            │
            ▼
         Grafana
```

These hostnames are currently intended for the local lab environment.

---

# Persistent Storage

Persistent storage will be implemented for stateful services such as:

- MySQL
- PostgreSQL
- Redis

The project will investigate Kubernetes storage concepts including:

- PersistentVolumes
- PersistentVolumeClaims
- StorageClasses
- Dynamic provisioning

---

# Monitoring

The monitoring stack will use:

- Prometheus
- Grafana

The goal is to monitor both the Kubernetes platform and the applications running on it.

Examples of monitored metrics include:

- Node CPU and memory usage
- Disk usage
- Pod health
- Pod restarts
- Application resource consumption
- Cluster resource utilization

Grafana dashboards will be used to visualize the collected metrics.

---

# Logging

Centralized logging is planned using the **ELK stack**.

The logging platform will provide a central location for collecting and investigating logs generated by:

- Kubernetes components
- Application containers
- Infrastructure services

---

# CI/CD and GitOps

Application deployment will be automated through a CI/CD pipeline.

The planned workflow is:

```text
Developer
    │
    ▼
GitHub Repository
    │
    ▼
GitHub Actions
    │
    ├── Run Tests
    ├── Build Container Image
    └── Push Image
             │
             ▼
      Container Registry
             │
             ▼
       Kubernetes Cluster
             │
             ▼
        Application
```

GitOps will be introduced later to manage Kubernetes deployments declaratively.

The project may use a GitOps tool such as Argo CD depending on the final implementation.

---

# Autoscaling

The platform will investigate Kubernetes autoscaling capabilities.

The planned implementation includes:

- Metrics Server
- Horizontal Pod Autoscaler
- Resource requests and limits
- Load testing

The objective is to demonstrate how applications can automatically scale based on resource utilization.

---

# Security

Security will be implemented progressively throughout the project.

Planned areas include:

- RBAC
- Kubernetes Secrets
- Network Policies
- Resource Quotas
- Namespace isolation
- Secure container configuration
- Linux host hardening

Security decisions and implementation details will be documented as the project progresses.

---

# Backup and Disaster Recovery

The project will include backup and recovery procedures for the Kubernetes environment.

Potential technologies include:

- Velero
- etcd snapshots

Failure scenarios will be intentionally tested, including:

- Worker node failure
- Pod failure
- Control-plane node failure
- Application recovery
- Data restoration

The goal is not only to create backups but also to **verify that the system can actually be recovered from them**.

---

# Project Phases

The project is being implemented incrementally.

## Phase 1 — Infrastructure

- Create VirtualBox VMs
- Configure networking
- Configure hostnames
- Configure static IP addresses
- Prepare Linux nodes
- Install containerd
- Configure required kernel/network settings

## Phase 2 — Kubernetes Cluster

- Install Kubernetes components
- Initialize the first control plane
- Join additional control-plane nodes
- Join worker nodes
- Configure Cilium
- Verify cluster health

## Phase 3 — High Availability

- Configure the Kubernetes API load balancer
- Verify API-server failover
- Test control-plane node failures
- Document the HA architecture

## Phase 4 — Cluster Organization

- Create namespaces
- Configure RBAC
- Define resource policies
- Configure Helm
- Install Headlamp

## Phase 5 — Application Platform

- Deploy Laravel
- Deploy Django
- Deploy React
- Deploy Redis
- Deploy RabbitMQ
- Deploy MySQL
- Configure Services, ConfigMaps, Secrets, and storage

## Phase 6 — Networking and Ingress

- Deploy an Ingress Controller
- Configure application routing
- Configure external load balancing
- Introduce HTTPS

## Phase 7 — Persistent Storage

- Configure StorageClasses
- Configure PersistentVolumes
- Configure PersistentVolumeClaims
- Test stateful applications

## Phase 8 — Monitoring

- Deploy Prometheus
- Deploy Grafana
- Create cluster dashboards
- Monitor application health

## Phase 9 — Logging

- Deploy the logging stack
- Collect application logs
- Collect infrastructure logs
- Create useful log queries and dashboards

## Phase 10 — CI/CD and GitOps

- Create GitHub Actions pipelines
- Build application container images
- Push images to a container registry
- Automate Kubernetes deployments
- Introduce GitOps

## Phase 11 — Autoscaling

- Install Metrics Server
- Configure resource requests and limits
- Configure Horizontal Pod Autoscaling
- Perform load tests

## Phase 12 — Security

- Configure RBAC
- Configure Network Policies
- Secure Secrets
- Apply namespace and resource isolation

## Phase 13 — Backup and Disaster Recovery

- Configure backups
- Create recovery procedures
- Test etcd/application backups
- Simulate node failures
- Perform restoration tests

## Phase 14 — Documentation

Document:

- Architecture
- Installation
- Configuration
- Deployment procedures
- Troubleshooting
- Monitoring
- Backup and recovery
- Lessons learned

---

# Repository Structure

The repository will be organized approximately as follows:

```text
8-apex/
│
├── docs/
│   ├── architecture/
│   ├── infrastructure/
│   ├── kubernetes/
│   ├── networking/
│   ├── storage/
│   ├── monitoring/
│   ├── logging/
│   ├── security/
│   └── disaster-recovery/
│
├── kubernetes/
│   ├── namespaces/
│   ├── ingress/
│   ├── monitoring/
│   ├── logging/
│   ├── laravel/
│   ├── django/
│   ├── react/
│   ├── redis/
│   ├── rabbitmq/
│   └── mysql/
│
├── scripts/
│
├── diagrams/
│
├── .github/
│   └── workflows/
│
└── README.md
```

---

# Current Status

> **Status: In Development**

The project is being implemented incrementally. Features listed above represent the current architecture and implementation plan; individual components will be marked as completed as they are implemented and tested.

### Progress

- [x] Initial architecture design
- [x] VirtualBox lab design
- [x] VM/network planning
- [ ] Kubernetes cluster installation
- [ ] High-availability control plane
- [ ] Cilium
- [ ] Namespace architecture
- [ ] Ingress
- [ ] Persistent storage
- [ ] Laravel deployment
- [ ] Django deployment
- [ ] React deployment
- [ ] Monitoring
- [ ] Logging
- [ ] CI/CD
- [ ] GitOps
- [ ] Autoscaling
- [ ] Security
- [ ] Backup
- [ ] Disaster recovery

---

# Learning Objectives

Through this project, I aim to gain practical experience in:

- Linux system administration
- Kubernetes administration
- Kubernetes networking
- Containerization
- High availability
- Load balancing
- Infrastructure monitoring
- Centralized logging
- Persistent storage
- CI/CD
- GitOps
- Security
- Backup and disaster recovery
- Production-oriented troubleshooting

The focus is not only on deploying services, but on understanding **why each component is needed, how the components interact, and how the platform behaves when something fails.**

---

# Project Philosophy

> **Build it. Break it. Understand it. Document it.**

8-Apex is a learning project, but it is intentionally designed around production concepts.

Whenever possible, the project will include failure testing, troubleshooting, and recovery rather than stopping once a service successfully starts.

The objective is to turn theoretical Kubernetes and DevOps knowledge into practical infrastructure engineering experience.
