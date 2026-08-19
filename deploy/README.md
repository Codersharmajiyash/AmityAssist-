# Phase 13 deployment

Copy `.env.production.example` to `.env.production`, replace every placeholder, then run:

```powershell
docker compose --env-file .env.production -f docker-compose.production.yml up --build
```

The PostgreSQL base schema and Phase 13 extension run on first database creation. Existing databases require the Phase 13 SQL migration to be applied by the deployment operator.

For Kubernetes, replace the placeholder image, domains, and secret values in `kubernetes/uniassist.yaml`, then apply it:

```powershell
kubectl create namespace uniassist
kubectl create configmap uniassist-db-schema --namespace uniassist `
  --from-file=01_schema.sql=backend/database/postgres_schema.sql `
  --from-file=02_phase13.sql=backend/database/postgres_phase13.sql
kubectl apply -f deploy/kubernetes/uniassist.yaml
```

The API has readiness and liveness probes at `/api/health`. PostgreSQL, Redis, and MinIO retain their data through persistent volume claims.

## Backup and restore

Create a PostgreSQL backup with `scripts/backup-postgres.ps1 -Container <postgres-container>`. The resulting dump is written under `backups/` and is intentionally ignored by Git. Restore is destructive and requires an explicit `-Force`: `scripts/restore-postgres.ps1 -Container <postgres-container> -BackupFile <file> -Force`.
