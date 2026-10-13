# VaultMesh — Multi-Tenant Data Protection Control Plane

[![Go Version](https://img.shields.io/badge/go-1.26+-00ADD8.svg?style=flat&logo=go)](https://golang.org)
[![Kafka](https://img.shields.io/badge/kafka-3.8+-231F20.svg?style=flat&logo=apachekafka)](https://kafka.apache.org)
[![PostgreSQL](https://img.shields.io/badge/postgres-16+-336791.svg?style=flat&logo=postgresql)](https://postgresql.org)
[![Redis](https://img.shields.io/badge/redis-7.2+-DC382D.svg?style=flat&logo=redis)](https://redis.io)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**VaultMesh** is a distributed, multi-tenant SaaS control plane designed for enterprise data protection operations. It coordinates and orchestrates backup schedules, protection jobs, recovery policies, and audit trails across hundreds of isolated customer organizations with strict tenant boundary enforcement, resilient event-driven execution, and zero-loss audit guarantees.

Built to showcase core infrastructure, distributed systems, and reliability engineering principles tailored for modern cloud data management platforms (e.g., Rubrik, AWS Backup).

---

## 1. System Architecture

```text
                             Client Applications / CLI
                                        │
                                        ▼ (HTTPS / REST)
                             ┌───────────────────────┐
                             │      API Gateway      │
                             │ (Rate Limiting, Auth) │
                             └──────────┬────────────┘
                                        │
           ┌────────────────────────────┼────────────────────────────┐
           ▼                            ▼                            ▼
┌────────────────────┐       ┌────────────────────┐       ┌────────────────────┐
│    Auth Service    │       │   Tenant Service   │       │   Policy Service   │
│   (JWT & RBAC)     │       │(Orgs, Quotas, Keys)│       │ (Schedules, Rules) │
└──────────┬─────────┘       └──────────┬─────────┘       └──────────┬─────────┘
           │                            │                            │
           └────────────────────────────┼────────────────────────────┘
                                        │
                                        ▼
                             ┌───────────────────────┐
                             │  Job Orchestrator API │
                             │(State Machine, Locks) │
                             └──────────┬────────────┘
                                        │
                                        ▼
                             ┌───────────────────────┐
                             │  Apache Kafka Cluster │
                             │  (Event Mesh Bus)     │
                             └──────┬─────────┬──────┘
                                    │         │
                jobs.triggered      │         │ audit.events
                                    ▼         ▼
                         ┌─────────────┐   ┌────────────────┐
                         │ Job Workers │   │ Audit Consumer │
                         │ (Idempotent,│   │  (Immutable    │
                         │ Retries,DLQ)│   │  Audit Trail)  │
                         └──────┬──────┘   └───────┬────────┘
                                │                  │
            ┌───────────────────┴──────────┐       │
            ▼                              ▼       ▼
    ┌───────────────┐              ┌────────────────┐
    │     Redis     │              │   PostgreSQL   │
    │(Locks & Cache)│              │(Tenant Storage)│
    └───────────────┘              └────────────────┘
```

---

## 2. Core Engineering Capabilities

### 🛡️ Multi-Tenancy & Strong Isolation
* **Context-Bound Tenant Resolution:** Every incoming request resolves a verified `TenantContext` containing `tenant_id`, org quotas, and role permissions.
* **Tenant-Scoped Persistence:** All database queries, indices, and transactions are strictly tenant-keyed (`tenant_id`), preventing cross-tenant leakage.
* **Per-Tenant Rate Limiting & Resource Quotas:** Redis token-bucket rate limiting prevents noisy-neighbor resource exhaustion.

### ⚡ Event-Driven Job Orchestration & Fault Tolerance
* **Asynchronous Kafka Event Bus:** Jobs transition asynchronously across decoupled topics (`jobs.triggered`, `jobs.completed`, `jobs.failed`, `jobs.dlq`).
* **Idempotent Consumers:** Deduplication keys via Redis & PostgreSQL ensure at-least-once Kafka delivery does not trigger duplicate backups.
* **Distributed Locking:** Redis-based distributed mutexes (`Redlock` pattern) prevent race conditions when concurrent triggers hit the same protection policy.
* **State Machine Integrity:** Enforces deterministic transitions: `PENDING` ➔ `QUEUED` ➔ `RUNNING` ➔ `COMPLETED` / `FAILED` / `RETRYING` ➔ `CANCELED`.
* **Exponential Backoff & Dead Letter Queue (DLQ):** Transient failures trigger bounded retries with jitter; exhausted retries automatically route to `jobs.dlq` for operator investigation.

### 🔐 Security, RBAC & Immutable Auditability
* **Role-Based Access Control (RBAC):** Fine-grained permission matrix across `TenantAdmin`, `BackupOperator`, `Auditor`, and `Viewer`.
* **Tamper-Evident Audit Trail:** Every action (policy edits, manual backup runs, recovery requests) emits an audit event consumed into append-only tables.

---

## 3. VaultMesh vs. RestoreForge

VaultMesh and [RestoreForge](https://github.com/vuday/RestoreForge) complement each other by addressing distinct layers of data protection infrastructure:

| Dimension | **RestoreForge** | **VaultMesh** |
| :--- | :--- | :--- |
| **Primary Scope** | **Data Plane (Storage Engine)** | **Control Plane (Orchestration Engine)** |
| **Core Challenge** | Content-addressed chunking, deduplication, MinIO storage & data integrity | Multi-tenant isolation, distributed state machines, Kafka event streaming |
| **Storage Architecture** | Object Storage (MinIO) + Content Metadata (PostgreSQL) | PostgreSQL (Relational metadata) + Redis (Locks & token buckets) |
| **Processing Paradigm** | Block/chunk-level pipeline with cryptographic verification | Event-driven microservices with at-least-once Kafka guarantees |
| **Key Distributed Concept** | Chunk-level deduplication, data corruption recovery | Idempotency, DLQ handling, tenant noisy-neighbor mitigation, distributed locks |

---

## 4. Technology Stack

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Language** | Go (1.26+) | High-concurrency control plane services and asynchronous consumers |
| **Message Broker** | Apache Kafka (KRaft mode) | Reliable, decoupled event streaming for job dispatch, state transitions, and audits |
| **Primary Database** | PostgreSQL 16+ | ACID relational store for tenants, policies, job states, and audit trails |
| **In-Memory Store** | Redis 7.2+ | Distributed mutual exclusion locks, consumer idempotency keys, and tenant rate limiting |
| **API Transport** | REST / JSON | HTTP APIs with structured JSON, standard error contracts, and middleware chains |
| **Auth & Security** | JWT + RBAC | Tenant-scoped claims with role enforcement |
| **Containerization** | Docker & Compose | Multi-container local orchestration for Kafka, Postgres, Redis, and services |

---

## 5. Repository Structure

```text
.
├── cmd/
│   ├── api/                    # REST API Gateway & Control Plane entrypoint
│   │   └── main.go
│   ├── worker/                 # Job execution worker (Kafka consumer + state updater)
│   │   └── main.go
│   └── audit/                  # Audit event consumer (Kafka consumer + DB writer)
│       └── main.go
├── internal/
│   ├── api/                    # HTTP presentation layer
│   │   ├── handlers/           # Route handlers (auth, tenant, policy, job, audit)
│   │   ├── middleware/         # Auth, TenantContext, RateLimit, Logging
│   │   └── router.go           # HTTP routing setup
│   ├── auth/                   # RBAC engine, JWT generation & verification
│   ├── tenant/                 # Tenant provisioning and quota services
│   ├── policy/                 # Backup policy definitions and schedules
│   ├── job/                    # State machine orchestrator & job management
│   ├── worker/                 # Job execution logic, retry policy & DLQ handler
│   ├── audit/                  # Audit logging service & querying
│   └── config/                 # Environment and application configuration
├── pkg/
│   ├── database/               # PostgreSQL connection pool & tenant query helpers
│   ├── kafka/                  # Kafka producer, consumer group wrapper, DLQ helper
│   ├── redis/                  # Redis client, distributed lock & idempotency store
│   └── models/                 # Shared domain models & event schemas
├── migrations/                 # PostgreSQL schema migrations (Up/Down)
│   ├── 000001_init_schema.up.sql
│   └── 000001_init_schema.down.sql
├── deployments/
│   ├── docker-compose.yml      # Kafka (KRaft), PostgreSQL, Redis, API, Worker, Audit
│   └── Dockerfile
├── scripts/
│   └── seed.sql                # Seed data for local validation
├── Makefile                    # Developer workflow targets (build, test, run, docker)
├── go.mod                      # Go module definition
└── README.md                   # System documentation
```

---

## 6. Getting Started

### Prerequisites
* **Go**: `1.24+` (or `1.26+`)
* **Docker & Docker Compose**: v2.20+
* **Make**: (Optional, for Makefile shortcuts)

### 1. Start Infrastructure Dependencies
Launch Kafka (KRaft mode), PostgreSQL, and Redis:
```bash
docker compose -f deployments/docker-compose.yml up -d postgres redis kafka
```

### 2. Run Database Migrations
Apply the initial schema:
```bash
# Using migrate tool or psql
docker exec -i vaultmesh-postgres psql -U vaultmesh -d vaultmesh < migrations/000001_init_schema.up.sql
docker exec -i vaultmesh-postgres psql -U vaultmesh -d vaultmesh < scripts/seed.sql
```

### 3. Run Services Locally
Open separate terminal tabs or run via Go:

```bash
# Terminal 1: API Server
go run cmd/api/main.go

# Terminal 2: Job Worker Consumer
go run cmd/worker/main.go

# Terminal 3: Audit Event Consumer
go run cmd/audit/main.go
```

Or run everything inside Docker:
```bash
docker compose -f deployments/docker-compose.yml up --build
```

---

## 7. API Specification Overview

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/auth/login` | Authenticate user & issue tenant-scoped JWT | No |
| `GET` | `/api/v1/tenants/me` | Fetch authenticated tenant details & quotas | `Viewer+` |
| `POST` | `/api/v1/policies` | Create new data protection policy | `TenantAdmin` |
| `GET` | `/api/v1/policies` | List all protection policies for tenant | `Viewer+` |
| `POST` | `/api/v1/jobs/trigger` | Manually dispatch a data protection job | `BackupOperator` |
| `GET` | `/api/v1/jobs/:id` | Get job lifecycle status & execution metadata | `Viewer+` |
| `GET` | `/api/v1/audit/logs` | Query tenant audit events | `Auditor+` |
| `GET` | `/healthz` | System health check (PostgreSQL, Kafka, Redis) | No |

---

## 8. Event Topics & Lifecycle

| Topic Name | Producer | Consumer | Description |
| :--- | :--- | :--- | :--- |
| `vaultmesh.jobs.triggered` | API Gateway | Job Workers | Emitted when a scheduled or manual job is queued |
| `vaultmesh.jobs.progress` | Job Workers | API / WebSocket | Real-time progress updates & chunk checkpointing |
| `vaultmesh.jobs.completed` | Job Workers | API / Audit | Emitted upon successful job termination |
| `vaultmesh.jobs.failed` | Job Workers | Job Workers | Emitted on transient failure for retry evaluation |
| `vaultmesh.jobs.dlq` | Job Workers | DLQ Monitor | Dead-letter queue for exhausted retries |
| `vaultmesh.audit.events` | All Services | Audit Consumer | Stream of all state mutations for compliance storage |

---

## 9. License

This project is licensed under the [MIT License](LICENSE).

#   V a l u t M e s h  
 