# DB Master-Slave Replication Training

This repository is a training ground for learning how to set up, configure, and manage **PostgreSQL Master-Slave Replication** using Docker and HAProxy.

## Architecture

The setup consists of the following components:

- **Primary Database (`db-primary`)**: 
  - The master PostgreSQL instance where all write operations occur.
  - Accessed via HAProxy (Write Endpoint).
  - Configured with `wal_level=replica` to support replication.

- **Replica Database (`db-replica`)**:
  - Read-only PostgreSQL instances that replicate data from the Primary.
  - Scalable (can run multiple instances).
  - Uses `pg_basebackup` to clone the primary's data on startup.

- **HAProxy (`haproxy`)**:
  - Load balancer that manages traffic to the database cluster.
  - **Write Endpoint (Port `5435`)**: Routes traffic to the Primary database.
  - **Read Endpoint (Port `5436`)**: Distributes read queries across Replica instances.
  - Stats Port: `8404`.

## Prerequisites

- [Docker](https://www.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)

## Getting Started

### 1. Start the Cluster

To start the full stack with 3 read replicas (as configured in HAProxy):

```bash
docker-compose up -d --build --scale db-replica=3
```

> **Note**: The HAProxy configuration expects 3 replicas (`replica-1`, `replica-2`, `replica-3`). If you run fewer, HAProxy will mark the missing ones as unhealthy but will still work with the available ones.
> 
> **Important**: The HAProxy configuration (`configs/haproxy.cfg`) assumes the project directory is named `db-master-slave-replication` (Docker Compose uses this as a prefix for container names). If you rename the directory, you must update the hostnames in `configs/haproxy.cfg` to match the new container names (e.g., `newdirname-db-replica-1`).

### 2. Check Status

Verify that all containers are running:

```bash
docker-compose ps
```

You can also check the HAProxy status page at [http://localhost:8404](http://localhost:8404) (no password by default) to see the health of the replicas.

---

## How to Test Replication

To confirm that replication is working, we will write data to the **Primary** database and read it from the **Replica** (via HAProxy).

### Step 1: Write to Primary (via HAProxy)

Connect to the HAProxy Write Endpoint (Port `5435`). This traffic is routed to the Primary database.

```bash
# Connect to Primary via HAProxy port
PGPASSWORD=mypassword psql -h localhost -p 5435 -U myuser -d mydatabase
```

Inside the SQL prompt:

```sql
-- Create a table
CREATE TABLE replication_test (
    id serial PRIMARY KEY,
    message text,
    created_at timestamp DEFAULT now()
);

-- Insert data
INSERT INTO replication_test (message) VALUES ('Hello from Primary!');
INSERT INTO replication_test (message) VALUES ('Replication is working?');
```

### Step 2: Read from Replicas (via HAProxy)

Connect to the HAProxy Load Balancer (Port `5436`). This traffic is routed to one of the available replicas.

```bash
# Connect to Replica via HAProxy port
PGPASSWORD=mypassword psql -h localhost -p 5436 -U myuser -d mydatabase
```

Inside the SQL prompt:

```sql
-- Check if data exists
SELECT * FROM replication_test;
```

**Result:** You should see the data you inserted in Step 1.

### Step 3: Verify Read-Only Mode on Replicas

Try to write data to the Replica endpoint inside the same session (Port 5436).

```sql
INSERT INTO replication_test (message) VALUES ('This should fail');
```

**Result:** You should receive an error similar to:
`ERROR:  cannot execute INSERT in a read-only transaction`

### Step 4: Verify Load Balancing

To see which replica is serving your request, run the following query multiple times from the HAProxy endpoint:

```sql
SELECT inet_server_addr();
```

If you have multiple replicas running, you should see different IP addresses returned as HAProxy balances the connections.

## Cleanup

To stop and remove all containers and volumes:

```bash
docker-compose down -v
```
