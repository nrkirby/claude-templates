---
name: postgres
description: >
  Deep PostgreSQL operational intuition — MVCC, VACUUM/autovacuum, WAL, checkpoints,
  streaming/logical replication, connection pooling (PgBouncer), deadlock diagnosis,
  memory layout, performance triage with pg_stat_statements.
  Load ONLY when the task is about deep operational tuning, incident diagnosis,
  replication lag, vacuum/autovacuum issues, WAL/checkpoint tuning, connection-pool
  sizing, or xid wraparound. Do NOT load for ordinary query writing, schema-first
  design, or standard indexing questions — those don't need this skill.
  Triggers on: "autovacuum lag", "table bloat", "dead tuples", "MVCC", "xid wraparound",
  "replication lag", "WAL bloat", "checkpoint tuning", "pgbouncer", "deadlock diagnosis",
  "pg_stat_statements", "pg_stat_replication", "vacuum stuck", "long-running transaction",
  "connection pool sizing".
credit: "Adapted from planetscale/database-skills (MIT), de-PlanetScale'd and trimmed for ct plugin."
---

# PostgreSQL Operational Guide

Concise operational pointers for deep Postgres troubleshooting and tuning.

Assumes you already know SQL, basic indexing, and how to read an `EXPLAIN ANALYZE`. This skill covers the **operational layer** — the parts models tend to gloss over: MVCC internals, vacuum behavior, WAL, replication, pooling.

## When to use

Load when the question is about:
- Autovacuum lag / bloat / dead tuples
- MVCC (xmin/xmax visibility, long transactions blocking vacuum, xid wraparound)
- WAL (bloat, checkpoint tuning, archiving, replication slots)
- Streaming / logical replication (lag diagnosis, slot management, failover)
- Connection pooling (PgBouncer sizing, transaction-pooling pitfalls)
- Deadlock diagnosis and lock waits
- Memory layout (shared_buffers, work_mem, effective_cache_size, OOM prevention)
- Storage internals (TOAST, fillfactor, tablespaces)
- Query-plan diagnosis via pg_stat_statements

**Do NOT load** for: writing SELECTs, schema design, index-type choice, typical EXPLAIN ANALYZE review, JOIN optimization — those don't need this skill.

## MVCC and autovacuum

- **Table bloat symptom** → Check `pg_stat_user_tables.n_dead_tup` and `last_autovacuum`. Long transactions hold the cleanup horizon — find via `SELECT * FROM pg_stat_activity WHERE backend_xmin IS NOT NULL` and consider `idle_in_transaction_session_timeout`.
- **Autovacuum formula**: `threshold = autovacuum_vacuum_threshold + autovacuum_vacuum_scale_factor × reltuples`. Default `scale_factor = 0.2` is too lazy for big tables — set per-table: `ALTER TABLE x SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_vacuum_threshold = 10000)`.
- **xid wraparound**: monitor `age(datfrozenxid)` vs `autovacuum_freeze_max_age` (default 200M). Near `vacuum_failsafe_age` (1.6B) Postgres enters single-user mode. `SELECT datname, age(datfrozenxid) FROM pg_database ORDER BY 2 DESC`.
- **Aggressive vacuum**: anti-wraparound vacuum cannot be cancelled and blocks DDL. Plan index/DDL windows around it.

## WAL and checkpoints

- **Checkpoint tuning**: set `max_wal_size` high enough that time-based checkpoints (`checkpoint_timeout`) fire before size-based ones. Observe via `log_checkpoints = on`.
- **WAL bloat culprits**: orphaned replication slots hold WAL forever. Find with `SELECT slot_name, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained FROM pg_replication_slots ORDER BY 3 DESC`. Drop abandoned slots.
- **`full_page_writes`**: do not disable unless the filesystem guarantees atomic writes at page size. Risk is torn pages on crash.
- **Archiving**: `archive_command` failures silently fill pg_wal. Monitor with `pg_stat_archiver` and the `last_failed_wal` / `last_failed_time` columns.

## Replication

- **Lag diagnosis**: `pg_stat_replication.{write_lag, flush_lag, replay_lag}`. Which lag is growing tells you where (network → write_lag; disk-sync → flush_lag; replay apply → replay_lag). All three equal → network bandwidth.
- **Logical replication**: `pg_replication_slots.confirmed_flush_lsn` and `pg_stat_subscription`. If the consumer stops, the slot retains WAL until disk fills — monitor retained size and set an upper-bound alert.
- **Synchronous replication**: `synchronous_commit = on` + `synchronous_standby_names`. A standby going offline with `on` blocks writes. If availability > durability, use `remote_write` or `local`.
- **Failover**: promote with `pg_promote()`; stop writes on the old primary before repointing traffic, or you'll split-brain.

## Connection pooling (PgBouncer)

- **Transaction pooling** (default mode): one backend per transaction. Incompatible with:
  - Prepared statements, unless `server_reset_query = DISCARD ALL` *or* PgBouncer 1.21+ with `max_prepared_statements > 0`
  - `SET LOCAL` persisting across transactions
  - Session-scope advisory locks
  - `LISTEN`/`NOTIFY`
- **Sizing rule of thumb**: `default_pool_size ≈ cores × 2 + effective_spindles` per (db, user). Larger pools cause tail-latency spikes, not throughput gains.
- **`max_client_conn`**: bounded by OS file descriptors — raise `ulimit -n` and `pgbouncer.ini` together. 10k+ client connections is normal.
- **Statement timeout at the pool layer**: `query_timeout`, `query_wait_timeout`. Use to avoid a single slow query pinning a backend.

## Deadlocks and lock waits

- **Enable diagnostics**: `log_lock_waits = on`, `deadlock_timeout = '1s'`. Deadlock reports include both query texts and the lock cycle.
- **Root cause**: inconsistent lock-acquisition ordering. Two transactions touching rows in A,B vs B,A order will deadlock. Enforce a canonical order (e.g., `ORDER BY id` before `SELECT FOR UPDATE`).
- **Spot lock waits live**: `SELECT * FROM pg_stat_activity WHERE wait_event_type = 'Lock'` joined with `pg_locks` on `pid`.

## Performance triage

**pg_stat_statements** is the single most useful extension for diagnosis.

Enable with `shared_preload_libraries = 'pg_stat_statements'`, `pg_stat_statements.track = 'all'`, restart required.

Top time-consumers:
```sql
SELECT query, calls, total_exec_time::int AS total_ms,
       mean_exec_time::int AS mean_ms, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

**Cache hit ratio** (target ≥ 0.99 for OLTP):
```sql
SELECT sum(blks_hit)::float / nullif(sum(blks_hit + blks_read), 0)
FROM pg_stat_database;
```

**Buffer cache sampling**:
```sql
CREATE EXTENSION pg_buffercache;
SELECT c.relname, count(*) AS buffers
FROM pg_buffercache b JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY 1 ORDER BY 2 DESC LIMIT 10;
```

## Memory layout

- `shared_buffers`: 25 % of RAM; diminishing returns beyond ~8-16 GB. OS page cache handles the rest.
- `work_mem`: per-operation, not per-query. Worst case: `max_connections × per-query-operators × work_mem`. Too high → OOM.
- `effective_cache_size`: 50-75 % of RAM. Planner hint only, not allocated.
- `maintenance_work_mem`: 256 MB - 1 GB for index build / vacuum speed.

## Storage internals

- **TOAST**: values > ~2 KB are moved to a sidecar table, compressed. Wide rows with large text/jsonb → check `pg_class.reltoastrelid` and `pg_relation_size(reltoastrelid)`.
- **fillfactor**: tune down (default 100 → 80-90) for tables with frequent `UPDATE`s to reserve HOT-update slots and reduce index churn.
- **Tablespaces**: only useful when different physical volumes actually differ in performance. Modern block storage makes this mostly obsolete.

## Authoritative references

**Official Postgres docs** (`postgresql.org/docs/current`):
- [Routine Vacuuming](https://www.postgresql.org/docs/current/routine-vacuuming.html)
- [WAL Configuration](https://www.postgresql.org/docs/current/wal-configuration.html)
- [Warm Standby / Streaming Replication](https://www.postgresql.org/docs/current/warm-standby.html#STREAMING-REPLICATION)
- [Logical Replication](https://www.postgresql.org/docs/current/logical-replication.html)
- [pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html)
- [MVCC](https://www.postgresql.org/docs/current/mvcc.html)
- [Monitoring stats](https://www.postgresql.org/docs/current/monitoring-stats.html)

**PgBouncer**: [pgbouncer.org/config.html](https://www.pgbouncer.org/config.html)

**Community operational deep-dives (reliable authors)**:
- Lukas Fittl (pganalyze blog) — MVCC/vacuum internals
- Haki Benita — query-plan reading, index strategies
- Tomas Vondra — performance internals

## Guardrails

Before recommending a non-trivial operational change (vacuum cost params, WAL params, replication config):
1. Quote the specific parameter name and its default
2. Cite the official Postgres doc section
3. Make the recommendation conditional on observed metrics — never blanket-tune

**Tuning without measurement is worse than defaults.**
