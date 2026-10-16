# SnapShare — Photo-Sharing App Scaling Plan

---

## 1. Assumptions

| Assumption                                                                                                                                    | Value                                                          |
| --------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| Registered users                                                                                                                              | 10,000,000                                                     |
| Daily-active users (DAU) — 10 % of registered                                                                                                 | **1,000,000**                                                  |
| Photos uploaded per active user per day                                                                                                       | 1                                                              |
| Feed pages viewed per active user per day                                                                                                     | 50                                                             |
| Average original photo size                                                                                                                   | 2 MB                                                           |
| Thumbnail size per photo                                                                                                                      | 50 KB                                                          |
| Peak multiplier (traffic spike factor)                                                                                                        | 5 × average                                                    |
| Days in a year                                                                                                                                | 365                                                            |
| Seconds in a day                                                                                                                              | 86,400                                                         |
| Read replica replication lag tolerance                                                                                                        | ≤ 1 second (eventual consistency is acceptable for feed reads) |
| Thumbnails are generated asynchronously after upload                                                                                          | yes                                                            |
| Users are spread across multiple time zones, so load is relatively uniform, but a single daily peak window is used as a conservative estimate | yes                                                            |

---

## 2. Estimates

### 2.1 Daily Active Users (DAU)

```
DAU = 10,000,000 × 10% = 1,000,000 users/day
```

### 2.2 Uploads Per Second

```
Total uploads/day = DAU × 1 upload = 1,000,000 uploads/day

Average upload rate = 1,000,000 ÷ 86,400 ≈ 11.6  → ~12 uploads/sec
Peak upload rate    = 12 × 5                       → ~60 uploads/sec
```

### 2.3 Feed Views Per Second

```
Total feed page views/day = DAU × 50 pages = 50,000,000 views/day

Average feed view rate = 50,000,000 ÷ 86,400 ≈ 578.7  → ~579 views/sec
Peak feed view rate    = 579 × 5                        → ~2,895 views/sec
```

### 2.4 Photo Storage Per Year

```
Photos stored per year       = 1,000,000 uploads/day × 365 days
                             = 365,000,000 photos/year

Original photo storage/year  = 365,000,000 × 2 MB  = 730,000,000 MB
                             ≈ 730 TB/year

Thumbnail storage/year       = 365,000,000 × 50 KB = 18,250,000,000 KB
                             ≈ 17.4 TB/year

Total storage/year           ≈ 730 TB + 17.4 TB
                             ≈ 747 TB/year  (~0.75 PB/year)
```

---

## 3. Read-Heavy or Write-Heavy?

**SnapShare is heavily read-heavy.**

| Metric                       | Rate        |
| ---------------------------- | ----------- |
| Writes (uploads) — average   | ~12 / sec   |
| Reads (feed views) — average | ~579 / sec  |
| Read : Write ratio           | **~48 : 1** |

### What this means for the design

Because reads outnumber writes by roughly 48 to 1, the system must be optimised for fast, scalable reads:

- **Caching** is the highest-leverage tool: serving a cached feed response costs almost nothing compared to a database query.
- **Read replicas** allow many parallel read queries to be distributed across multiple database nodes without overloading the primary.
- **A CDN** eliminates the majority of photo-serving load from the origin entirely, because the same popular photos are requested by many users.
- Write throughput (~60 uploads/sec at peak) is modest enough that a single primary database and an async thumbnail queue can handle it comfortably.

---

## 4. Why Photos Must Not Be Stored in the Database

Relational and even document databases are designed for structured, frequently-queried data (rows of metadata). Storing binary photo blobs inside the database causes several critical problems:

1. **Bloat and slow backups** — the database grows by ~730 TB per year, making backups, restores, and schema migrations extremely slow.
2. **Memory waste** — database engines cache frequently-accessed rows in RAM. Caching 2 MB photo blobs evicts thousands of small metadata rows, destroying query performance.
3. **Inefficient transfer** — the database becomes a bottleneck for every byte of every photo served; it was never designed to stream large files to many concurrent clients.
4. **Cost** — database storage and IOPS are far more expensive than object storage (e.g., AWS S3 charges ~$0.023/GB vs ~$0.08/GB for EBS).

**Photos (original and thumbnails) should be stored in object storage** (e.g., AWS S3, Google Cloud Storage, or Cloudflare R2) and delivered through a CDN. Only the photo's metadata (owner, timestamp, URL, like count, etc.) lives in the database.

---

## 5. Architecture Diagram

```
                        ┌─────────────────────────────────────────┐
                        │               Clients                   │
                        │   (mobile apps, web browsers)           │
                        └──────────────┬──────────────────────────┘
                                       │  HTTPS requests
                                       ▼
                        ┌─────────────────────────────────────────┐
                        │                 CDN                     │
                        │   (Cloudflare / CloudFront)             │
                        └──────────────┬──────────────────────────┘
                       Cache hit ◄─────┤ Cache miss
                                       ▼
                        ┌─────────────────────────────────────────┐
                        │           Load Balancer                 │
                        │   (AWS ALB / Nginx — round-robin)       │
                        └────┬──────────────┬───────────┬─────────┘
                             │              │           │
                    ┌────────▼──┐   ┌───────▼───┐  ┌───▼───────┐
                    │ App Server│   │ App Server│  │App Server │
                    │  (Node.js)│   │  (Node.js)│  │ (Node.js) │
                    └────┬──────┘   └─────┬─────┘  └─────┬─────┘
                         │                │               │
               ┌─────────▼────────────────▼───────────────▼──────┐
               │                                                   │
     ┌─────────▼──────────┐                       ┌───────────────▼──────┐
     │       Cache         │                       │   Message Queue      │
     │  (Redis)            │                       │  (RabbitMQ / SQS)    │
     └─────────────────────┘                       └───────────┬──────────┘
                                                               │
                                                   ┌───────────▼──────────┐
                                                   │   Thumbnail Worker   │
                                                   │  (reads original,    │
                                                   │   writes thumbnail)  │
                                                   └───────────┬──────────┘
               ┌────────────────────────────────────────────┐  │
               │              Database Layer                 │  │
               │  ┌─────────────────┐  ┌─────────────────┐  │  │
               │  │  Primary DB     │  │  Read Replica   │  │  │
               │  │  (PostgreSQL)   │─►│  (PostgreSQL)   │  │  │
               │  │  Writes only    │  │  Reads only     │  │  │
               │  └─────────────────┘  └─────────────────┘  │  │
               └────────────────────────────────────────────┘  │
                                                                │
               ┌────────────────────────────────────────────────▼──┐
               │               Object Storage                       │
               │       (AWS S3 / Google Cloud Storage)              │
               │   originals/      thumbnails/                      │
               └────────────────────────────────────────────────────┘
```

API and feed requests follow the CDN → load balancer → app-server path. Upload
bytes take a separate direct path from the client to object storage using the
pre-signed URL; object storage then emits an upload-complete event to the
message queue.

---

## 6. Component Explanations (One Sentence Each)

| Component                                      | Problem it solves                                                                                                                                                 |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **CDN** (Cloudflare / CloudFront)              | Caches and serves photos and static assets from edge nodes close to users, eliminating most origin traffic and dramatically reducing latency worldwide.           |
| **Load Balancer** (AWS ALB)                    | Distributes incoming HTTP requests evenly across multiple app servers so no single server becomes a bottleneck or single point of failure.                        |
| **App Servers** (Node.js, horizontally scaled) | Execute business logic — authenticating users, reading/writing metadata, generating signed upload URLs, and composing feed responses.                             |
| **Cache** (Redis)                              | Stores frequently-read data (user feeds, photo metadata, follower lists) in memory so most read requests never touch the database.                                |
| **Primary Database** (PostgreSQL)              | Durably stores all structured metadata — users, photos, follows, likes — and is the single authoritative source of truth for all writes.                          |
| **Read Replica** (PostgreSQL)                  | Receives a continuous stream of changes from the primary and handles all read queries, offloading the primary so it can focus on writes.                          |
| **Object Storage** (AWS S3)                    | Stores all binary photo files (originals and thumbnails) cheaply and durably at petabyte scale, with direct HTTP access so files bypass the app servers entirely. |
| **Storage Event Notification** (S3 Events)     | Publishes a durable upload-complete event to the message queue after an original photo is successfully written to object storage.                                  |
| **Message Queue** (AWS SQS / RabbitMQ)         | Decouples the upload path from thumbnail generation, ensuring that slow or failed thumbnail jobs do not block the user's upload response.                         |
| **Thumbnail Worker**                           | Consumes jobs from the queue, downloads the original from object storage, resizes it to a thumbnail, and uploads the result back to object storage.               |

---

## 7. Upload Flow — Step by Step

```
Step 1 — Client requests upload
  The mobile app sends a POST /photos/upload-url request to the Load Balancer,
  which routes it to an available App Server.

Step 2 — App Server generates a pre-signed URL
  The App Server authenticates the user, creates a photo metadata record
  (status = "processing") in the Primary Database, and returns a short-lived
  pre-signed S3 URL directly to the client.

Step 3 — Client uploads directly to Object Storage
  The client uses the pre-signed URL to PUT the 2 MB photo file directly to
  S3, bypassing the App Servers entirely — this keeps app server bandwidth low.

Step 4 — S3 triggers an upload-complete event
  When the upload finishes, S3 publishes an event (via S3 Event Notification)
  to the Message Queue (SQS), carrying the bucket name and object key.

Step 5 — Worker picks up the job
  A Thumbnail Worker polls the SQS queue, receives the message, and downloads
  the original photo from S3.

Step 6 — Thumbnail generation
  The worker uses an image-processing library (e.g., Sharp) to resize the photo
  to thumbnail dimensions (e.g., 400 × 400 px, ~50 KB) and uploads the thumbnail
  to S3 under a separate thumbnails/ prefix.

Step 7 — Metadata updated
  The worker updates the photo record in the Primary Database: thumbnail URL is
  set and status changes from "processing" to "published".

Step 8 — Cache invalidated / feed updated
  The worker (or App Server) invalidates or updates any cached feed entries for
  the uploader's followers, so the new photo appears on their feeds.

Step 9 — Photo served to followers
  When a follower scrolls their feed, the App Server returns cached thumbnail
  URLs from Redis; the CDN serves the thumbnail bytes from the nearest edge node,
  and full-resolution photos are served from S3 via the CDN only when explicitly
  opened.
```

---

## 8. Trade-offs

### Trade-off 1 — Eventual Consistency in the Feed (Cache vs. Freshness)

**Decision:** Feed responses are cached in Redis for 30–60 seconds, and read replicas may lag the primary by up to 1 second.

**Benefit:** This dramatically reduces database load. At ~579 feed views/sec, a 60-second TTL means each unique feed computation hits the database at most once per minute per user instead of 579 times. This is what makes the system affordable to operate.

**Cost:** A follower might not see a newly uploaded photo for up to a minute after it is published. For a social feed, this staleness is generally acceptable — users do not expect real-time precision — but it would be unacceptable in a financial transaction system.

---

### Trade-off 2 — Asynchronous Thumbnail Generation (Queue vs. Synchronous Processing)

**Decision:** Thumbnail creation happens asynchronously via a queue and worker, not inline during the upload request.

**Benefit:** The user receives an upload confirmation almost instantly (after the S3 PUT completes) without waiting for image processing, which can take several seconds per photo. The queue also provides automatic retry logic if a worker crashes mid-job, improving reliability.

**Cost:** There is a brief window (typically a few seconds) after upload where the thumbnail does not exist yet. The app must handle this gracefully — for example, by showing a placeholder or the full-resolution image — which adds frontend complexity. If the worker falls behind during a traffic spike, the delay could grow to minutes.

---

### Trade-off 3 — Managed Object Storage vs. Self-Hosted File Servers

**Decision:** Store photos in managed object storage (S3) and serve them through a CDN rather than hosting files on the app servers' local disks.

**Benefit:** Object storage scales to petabytes with no operational overhead; the CDN absorbs virtually all photo-serving bandwidth at the edge, so origin servers are rarely touched for popular photos. Durability is extremely high (S3 offers 99.999999999 % — "11 nines").

**Cost:** Every photo access requires an external network call (app server → S3 or CDN → client), introducing a small latency dependency on third-party infrastructure. The system also incurs per-request and per-GB egress costs that a fully self-hosted solution would not.

---

_End of SnapShare Scaling Plan_
