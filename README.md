# General Ideaa
This is a basic k8s cluster project setup and desiging or operate of a production-like k8s platform which is going to help me build a whole infrastructure from the scratch and improve in my DevOps skills.

although for now I've planned to implement it localy on VirtualBox machines but It'll grow.

# project 8-Apex
The project's name is **8-Apex** means k8s at it's highst level of response and functioning.

8-Apex is not just about k8s cluster but a whole ready platform to host multiple production applicatons with the implementations of automated deployment and tools to maintain and monitor your applicatoins; for example it consists of:
 - loggin and monitroing stacks
 - prepared container images
 - CI/CD piplines and automated deployments
 - persistant data storage solutions
 - backups
 - high availabel cluster control planes
 - application LoadBalancer


### structure
the cluster schema would contain two load balanced Control-planes and 3 Worker-nodes with with one applicatin level load balancer for entry point of traffic:
```
         kubectl
            |
      api-server LB
            |
   ┌────────┴────────┐
   |                 |
  CP-1              CP-2
(api-server)      (api-server)
   │                 │
   └────────┬────────┘
            |    
   ┌────────┴────────┐
   |        |        |
   |        |        |
Node1     Node2     Node3
(pods)    (pods)    (pods)
   |        |        |
   |        |        |      CLUSTER
------------------------------------
   |        |        |      INTERNET
   |        |        |
   └────────┬────────┘
            |
      Application-LB
            |
            |
         Traffic
```

### VM settings
each VM is Rocky-10.2 minimal. physical network settings for VM's are two Interface for each VM. one NAT and one host-only which hostonly is specified as the node's main IP address and NAT interface is not used (just for local internet checks and tests).


### cluster Details
- cluster is created using **kubeadm**
- CRI is **containerd**
- CNI is **Cilium**
- **Helm** as package manager
- **HeadLamp** as visual dashboard
- seprated **namespaces** for each environments:
    * production
    * staging
    * monitoring
    * ingress
    * database
    * logging
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
