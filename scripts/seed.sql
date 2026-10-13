-- Seed data for VaultMesh local testing
INSERT INTO tenants (id, name, plan, max_policies, max_concurrent_jobs, status)
VALUES 
    ('a0000000-0000-0000-0000-000000000001', 'Acme Corp', 'enterprise', 100, 20, 'active'),
    ('b0000000-0000-0000-0000-000000000002', 'Stark Industries', 'standard', 50, 10, 'active')
ON CONFLICT (id) DO NOTHING;

-- Passwords are bcrypt hashes for 'password123'
INSERT INTO users (id, tenant_id, email, password_hash, role)
VALUES 
    ('c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'admin@acme.com', '$2a$10$w09ZlD2O0wKqTf9qYfE11O3rD4BvYhL9VfB.0qL.5vN5hC2YhG.0m', 'TenantAdmin'),
    ('c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'operator@acme.com', '$2a$10$w09ZlD2O0wKqTf9qYfE11O3rD4BvYhL9VfB.0qL.5vN5hC2YhG.0m', 'BackupOperator'),
    ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', 'admin@stark.com', '$2a$10$w09ZlD2O0wKqTf9qYfE11O3rD4BvYhL9VfB.0qL.5vN5hC2YhG.0m', 'TenantAdmin')
ON CONFLICT (id) DO NOTHING;

INSERT INTO policies (id, tenant_id, name, description, cron_schedule, retention_days, backup_type, target_resource, is_enabled)
VALUES 
    ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Daily DB Snapshot', 'Daily backup of production database', '0 2 * * *', 30, 'snapshot', 'db-cluster-prod-01', true),
    ('d0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'Hourly Filesystem Backup', 'Continuous hourly snapshots', '0 * * * *', 14, 'snapshot', 'fs-volume-stark-core', true)
ON CONFLICT (id) DO NOTHING;

