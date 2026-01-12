# s3-data-transfer

A lightweight automation toolkit for synchronizing data between local platforms and S3-compatible object storage.  
It provides upload and download scripts that coordinate transfers using a two-bucket control mechanism — ensuring reliable, traceable, and permission-separated data exchange between systems.

---

## Overview

The repository contains two main shell scripts and two configuration templates:

| File | Description |
|------|--------------|
| `upload-data-to-s3.sh` | Uploads data directories from a source platform to an S3 data bucket and logs metadata into a control bucket. |
| `download-data-from-s3.sh` | Downloads available datasets from the data bucket by reading control information, and notifies completion back to the uploader. |
| `connection-test.sh` | Tests your credentials to both buckets and its permissions (read, write, list). |
| `config.cfg.sample` | Example environment configuration defining paths, tenant IDs, and runtime variables. |
| `rclone.config.sample` | Example configuration for `rclone`, used to authenticate with S3-compatible endpoints. |

---

## Architecture

### Conceptual Overview

The workflow uses two S3 buckets per tenant:

- **Data Bucket (`<producer>-<tenant>-databucket`)** — stores the actual datasets.  
- **Control Bucket (`<producer>-<tenant>-controlbucket`)** — used to exchange control files and track workflow state.

Each dataset progresses through a defined sequence of lifecycle states:

```
created → uploading → uploaded → downloading → downloaded → deleted
```

### Data Flow Diagram

Below is a simplified view of how data and control messages move between systems:

```
          ┌────────────────────┐
          │   Uploading Host   │
          │  (data producer)   │
          └────────┬───────────┘
                   │
                   │ 1. Upload dataset
                   ▼
          ┌────────────────────┐
          │    Data Bucket     │
          │ <producer>-<tenant>-databucket
          └────────────────────┘
                   │
                   │ 2. Write control info
                   ▼
          ┌────────────────────┐
          │   Control Bucket   │
          │ <producer>-<tenant>-controlbucket
          └────────┬───────────┘
                   │
                   │ 3. Control info synced
                   ▼
          ┌────────────────────┐
          │  Downloading Host  │
          │  (data consumer)   │
          └────────┬───────────┘
                   │
                   │ 4. Download dataset
                   ▼
          ┌────────────────────┐
          │  Data Bucket (RO)  │
          └────────┬───────────┘
                   │
                   │ 5. Notify completion
                   ▼
          ┌────────────────────┐
          │   Control Bucket   │
          └────────────────────┘
```

**Access roles:**
- The **uploader** has **read/write** access to both buckets.  
- The **downloader** has **read-only** access to the data bucket and **read/write** access to the control bucket.

---

## Quick Start

### 1. Install Dependencies

Make sure [`rclone`](https://rclone.org/downloads/) is installed and available in your `$PATH`:

```bash
sudo apt install rclone
# or
brew install rclone
```

### 2. Clone This Repository

```bash
git clone https://github.com/mdc-berlin/s3-data-transfer.git
cd s3-data-transfer
```

### 3. Configure Your Environment

Copy and edit the sample configuration files:

```bash
cp config.cfg.sample config.cfg
```

Edit `config.cfg` to reflect your environment:

```bash
tenant="example"
temppath="/tmp/s3-transfer"
sourcepath="/data/workflows"
maxdepth=3
marker="workflow-progress.txt"
```

### 4. Upload Data

Prepare your dataset folder structure:

```
/data/workflows/
 ├─ dataset_A/
 │   └─ workflow-progress.txt
 ├─ dataset_B/
 │   └─ workflow-progress.txt
```

Then start the upload:

```bash
./upload-data-to-s3.sh ./config.cfg
```

This will:
- Find all workflow marker files  
- Upload datasets to the data bucket  
- Record timestamps and status in both control and workflow files

### 5. Download Data

On the receiving system, run:

```bash
./download-data-from-s3.sh ./config.cfg
```

This will:
- Read control metadata  
- Download available datasets  
- Notify the uploader by updating control files

### 6. Automate (Optional)

You can schedule uploads and downloads periodically using `cron` or `systemd timers`.  
Example `cron` entry (every 30 minutes):

```bash
*/30 * * * * /path/to/s3-data-transfer/upload-data-to-s3.sh /path/to/config.cfg >> /var/log/s3-upload.log 2>&1
```

---

## Workflow Summary

### Upload Phase
- Scans for directories containing a marker file (e.g., `workflow-progress.txt`)
- Uploads new datasets to the **data bucket**
- Updates workflow and control metadata

### Download Phase
- Checks for datasets marked as `uploaded`
- Downloads corresponding datasets
- Marks them as `downloaded` in the control bucket

### Cleanup (optional)
- Once a dataset is confirmed as downloaded, it can be removed from both buckets

---

## Notes

- Control files serve as the **only communication channel** between uploader and downloader.  
- The workflow supports **incremental re-runs** — previously processed datasets are skipped.  
- Both scripts are designed to be **idempotent** and safe for repeated execution.  
- The scripts are intentionally lightweight, with minimal dependencies.
