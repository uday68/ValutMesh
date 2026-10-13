# VaultMesh

> A multi-tenant data-protection control plane for orchestrating backup policies, protection jobs, recovery workflows, and compliance-oriented audit events.

[![Go](https://img.shields.io/badge/Go-1.26.1-00ADD8?logo=go&logoColor=white)](https://go.dev/)
[![Kafka](https://img.shields.io/badge/Apache%20Kafka-KRaft-231F20?logo=apachekafka&logoColor=white)](https://kafka.apache.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-7.2-DC382D?logo=redis&logoColor=white)](https://redis.io/)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-supported-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)

## Why VaultMesh?

VaultMesh models the **control-plane responsibilities of a modern data-protection platform**. It separates policy and job orchestration from the underlying storage/data plane, allowing protection operations to be scheduled, dispatched, retried, audited, and isolated across tenants.

The project is intentionally designed around the engineering concerns expected in enterprise backup and cyber-resilience systems, including:

- Multi-tenant isolation and noisy-neighbor protection
- Reliable asynchronous job orchestration
- Idempotent event consumption and at-least-once delivery
- Distributed locking and concurrency control
- Retry policies and dead-letter queues
- Role-based access control and tenant-scoped authorization
- Immutable, compliance-oriented audit history
- Containerized local development and repeatable validation

## Rubrik-Relevant Engineering Signals

This project demonstrates concepts directly relevant to enterprise data security and data-management platforms such as Rubrik:

| Capability | VaultMesh implementation focus |
| --- | --- |
| **Policy-driven protection** | Tenant-scoped protection policies and scheduled/manual job triggers |
| **Distributed orchestration** | Kafka-backed job dispatch with explicit lifecycle transitions |
| **Resilience** | Idempotent consumers, bounded retries, jitter, and DLQ handling |
| **Tenant isolation** | Tenant-bound request context, persistence, quotas, and authorization |
| **Operational correctness** | Redis distributed locks and duplicate-delivery protection |
| **Security** | JWT authentication, RBAC, and least-privilege role checks |
| **Compliance** | Append-only audit events for policy and job state mutations |
| **Production readiness** | Health checks, Docker Compose dependencies, and Makefile automation |

## Architecture

```text
                         Clients / CLI
                              |
                         HTTPS / REST
                              v
                    +--------------------+
                    |     API Gateway    |
                    | Auth, RBAC, Limits |
                    +----------+---------+
                               |
          +--------------------+--------------------+
          |                    |                    |
          v                    v                    v
   Auth Service        Tenant Service        Policy Service
   JWT + RBAC          Quotas + Keys         Schedules + Rules
          \                    |                    /
           +-------------------+-------------------+
                               v
                    +--------------------+
                    |  Job Orchestrator  |
                    | State + Locks      |
                    +----------+---------+
                               |
                               v
                    +--------------------+
                    | Apache Kafka / KRaft|
                    | Event Mesh          |
                    +-----+-----------+---+
                          |           |
                          v           v
                   Job Workers   Audit Consumer
                   Retry + DLQ   Immutable Trail
                          |           |
                          +-----+-----+
                                |
                 +--------------+--------------+
                 |                             |
                 v                             v
          Redis: locks, cache,             PostgreSQL:
          idempotency, quotas              tenants, policies, jobs, audit
```

## Core Design Principles

### Multi-tenant isolation

- Resolve every request into a verified tenant context.
- Scope authorization, persistence, quotas, and operational limits by `tenant_id`.
- Use Redis-backed rate limiting to reduce noisy-neighbor impact.

### Reliable job orchestration

Protection jobs follow an explicit lifecycle:

```text
PENDING -> QUEUED -> RUNNING -> COMPLETED
                         |          |
                         v          v
                      RETRYING    FAILED
                         |
                         v
                        DLQ

Any active job may be cancelled when policy and authorization permit it.
```

The design emphasizes deterministic state transitions, idempotency keys, distributed locks, bounded retries, and operator-visible failure handling.

### Security and auditability

- JWT-based authentication with tenant-scoped claims
- RBAC roles such as `TenantAdmin`, `BackupOperator`, `Auditor`, and `Viewer`
- Protected policy, job, tenant, and audit operations
- Audit events for policy changes, manual runs, recovery requests, and state mutations

## Technology Stack

| Layer | Technology | Purpose |
| --- | --- | --- |
| Services | Go 1.26.1 | Concurrent APIs, workers, and event consumers |
| API | REST / JSON | Control-plane operations and health checks |
| Eventing | Apache Kafka in KRaft mode | Decoupled job, progress, failure, and audit events |
| Relational storage | PostgreSQL 16 | Tenant, policy, job, and audit metadata |
| Coordination | Redis 7.2 | Locks, rate limits, cache, and idempotency records |
| Local environment | Docker Compose | Reproducible infrastructure dependencies |
| Developer workflow | Make | Build, test, run, and container lifecycle commands |

## Repository Layout

```text
.
├── cmd/
│   ├── api/                  # REST API and control-plane entrypoint
│   ├── worker/               # Protection-job consumer and executor
│   └── audit/                # Audit-event consumer and persistence
├── internal/
│   ├── api/                  # Handlers, middleware, and routing
│   ├── auth/                 # JWT and RBAC logic
│   ├── tenant/               # Tenant provisioning and quotas
│   ├── policy/               # Protection policies and schedules
│   ├── job/                  # Job state machine and orchestration
│   ├── worker/               # Retry, DLQ, and execution logic
│   ├── audit/                # Audit recording and query logic
│   └── config/               # Application configuration
├── pkg/
│   ├── database/             # PostgreSQL access and tenant helpers
│   ├── kafka/                # Producers, consumers, and DLQ helpers
│   ├── redis/                # Locks, cache, and idempotency helpers
│   └── models/               # Shared domain models and event schemas
├── deployments/
│   ├── docker-compose.yml    # PostgreSQL, Redis, and Kafka
│   └── Dockerfile            # Multi-stage service image
├── migrations/               # Database schema migrations
├── scripts/                  # Seed data and local validation helpers
├── docs/                     # Additional design documentation
├── Makefile                  # Standard developer commands
├── go.mod                    # Go module definition
└── README.md                 # Project documentation
```

## Quick Start

### Prerequisites

- Go 1.26.1 or later
- Docker Engine and Docker Compose v2
- GNU Make (recommended)

### 1. Start the local infrastructure

```bash
git clone https://github.com/uday68/ValutMesh.git
cd ValutMesh
make docker-up
```

This starts PostgreSQL, Redis, and Kafka using `deployments/docker-compose.yml`. PostgreSQL initializes the schema and seed data from `migrations/` and `scripts/`.

### 2. Build and test

```bash
make build
make test
```

The test target runs the Go test suite with verbose output and the race detector:

```bash
go test -v -race ./...
```

### 3. Run services locally

Use separate terminals for the API, worker, and audit consumer:

```bash
make run-api
make run-worker
make run-audit
```

Or build/run a service image with the Dockerfile's `SERVICE` argument:

```bash
docker build -f deployments/Dockerfile --build-arg SERVICE=api -t vaultmesh-api .
docker run --rm -p 8080:8080 vaultmesh-api
```

### 4. Stop the environment

```bash
make docker-down
```

## Makefile Commands

| Command | Description |
| --- | --- |
| `make build` | Build API, worker, and audit binaries into `bin/` |
| `make test` | Run tests with verbose output and the race detector |
| `make clean` | Remove generated binaries |
| `make run-api` | Run the API service |
| `make run-worker` | Run the job worker |
| `make run-audit` | Run the audit consumer |
| `make docker-up` | Start local infrastructure in the background |
| `make docker-down` | Stop and remove local containers |

## API Surface

| Method | Endpoint | Purpose | Access |
| --- | --- | --- | --- |
| `POST` | `/api/v1/auth/login` | Authenticate and issue a tenant-scoped JWT | Public |
| `GET` | `/api/v1/tenants/me` | Read tenant identity and quotas | Viewer+ |
| `POST` | `/api/v1/policies` | Create a protection policy | TenantAdmin |
| `GET` | `/api/v1/policies` | List tenant policies | Viewer+ |
| `POST` | `/api/v1/jobs/trigger` | Trigger a protection job | BackupOperator |
| `GET` | `/api/v1/jobs/:id` | Inspect job state and metadata | Viewer+ |
| `GET` | `/api/v1/audit/logs` | Query audit events | Auditor+ |
| `GET` | `/healthz` | Check service and dependency health | Public |

## Event Model

| Topic | Producer | Consumer | Purpose |
| --- | --- | --- | --- |
| `vaultmesh.jobs.triggered` | API | Workers | Dispatch scheduled or manual jobs |
| `vaultmesh.jobs.progress` | Workers | API / clients | Publish execution progress |
| `vaultmesh.jobs.completed` | Workers | API / audit | Record successful completion |
| `vaultmesh.jobs.failed` | Workers | Workers | Evaluate retry eligibility |
| `vaultmesh.jobs.dlq` | Workers | Operations | Surface exhausted failures |
| `vaultmesh.audit.events` | Services | Audit consumer | Persist security and compliance events |

## Evaluation Checklist

A reviewer can validate the project with the following workflow:

```bash
make docker-up
make build
make test
make docker-down
```

Key areas to evaluate:

- Tenant context is enforced at API and persistence boundaries.
- Job transitions are deterministic and invalid transitions are rejected.
- Duplicate Kafka deliveries do not create duplicate work.
- Concurrent triggers for the same policy are protected by distributed locking.
- Retryable failures use bounded backoff and eventually reach the DLQ.
- Authorization is role-aware and tenant-scoped.
- Audit events capture meaningful state changes without becoming mutable business records.
- Health checks expose dependency failures clearly.

## Project Positioning

VaultMesh is the **control plane** for protection operations. A complementary data-plane implementation would handle content chunking, deduplication, object storage, encryption, integrity verification, and restore streams. Keeping these responsibilities separate makes the system easier to scale, test, secure, and operate.

## Status

This repository is an engineering portfolio project and architecture-focused reference implementation. Interfaces and service behavior may evolve as additional production-grade features are added.

## License

No license file is currently included in the repository. Add a `LICENSE` file before distributing VaultMesh for external use.
