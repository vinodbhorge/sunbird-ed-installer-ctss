# Module Configuration Guide

## Overview

All infrastructure is configured from a **single file**:

```
opentofu/aws/template/global-values.yaml
```

You never need to edit any `.tf` file for day-to-day provisioning changes.
This guide covers the **Network** and **Storage** modules in detail.

---

## Table of Contents

1. [Network Module](#1-network-module)
   - [How it works](#how-it-works)
   - [Scenario A — All Public](#scenario-a--all-public-subnets)
   - [Scenario B — All Private (Isolated)](#scenario-b--all-private-subnets-isolated)
   - [Scenario C — Mixed Public + Private with NAT](#scenario-c--mixed-public--private-with-nat-gateway)
   - [Scenario D — Bring Your Own VPC](#scenario-d--bring-your-own-vpc)
   - [Field Reference](#subnet_config-field-reference)
   - [Auto-provisioned resources](#what-gets-provisioned-automatically)
2. [Storage Module](#2-storage-module)
   - [How it works](#how-it-works-1)
   - [Scenario A — All Public](#scenario-a--all-public-buckets)
   - [Scenario B — All Private](#scenario-b--all-private-buckets)
   - [Scenario C — Mixed Public + Private](#scenario-c--mixed-public--private)
   - [Field Reference](#buckets-field-reference)
   - [Auto-provisioned resources](#what-gets-provisioned-automatically-1)
3. [Full global-values.yaml Reference](#3-full-global-valuesyaml-reference)
4. [Module Outputs Reference](#4-module-outputs-reference)

---

## 1. Network Module

### How it works

Define your subnets under `global.subnet_config`. Each entry is a logical name
mapped to a `type`, an availability zone suffix, and a unique CIDR offset.

The subnet CIDR is derived automatically by OpenTofu:

```
cidrsubnet(vpc_cidr, 8, cidr_netnum)
```

With the default VPC CIDR `10.0.0.0/16`:

| `cidr_netnum` | Subnet CIDR |
|---|---|
| 101 | `10.0.101.0/24` |
| 102 | `10.0.102.0/24` |
| 201 | `10.0.201.0/24` |
| 202 | `10.0.202.0/24` |

> Every `cidr_netnum` across all subnets must be unique — OpenTofu will
> raise a validation error at plan time if duplicates are found.

---

### Scenario A — All Public Subnets

Subnets receive public IPs and route through an Internet Gateway.
No NAT Gateway or private route table is created.

```yaml
global:
  create_network: true

  subnet_config:
    public-a:
      type: public
      availability_zone: "a"
      cidr_netnum: 101
    public-b:
      type: public
      availability_zone: "b"
      cidr_netnum: 102
```

**Resources provisioned:** VPC · IGW · 2 subnets · 1 public route table
with `0.0.0.0/0 → IGW` · security group

---

### Scenario B — All Private Subnets (Isolated)

Subnets have no public IPs and no internet egress.
Suitable for internal-only workloads or cost-sensitive non-prod environments.

```yaml
global:
  create_network: true
  nat_gateway_enabled: false    # prevents NAT GW creation

  subnet_config:
    private-a:
      type: private
      availability_zone: "a"
      cidr_netnum: 201
    private-b:
      type: private
      availability_zone: "b"
      cidr_netnum: 202
```

**Resources provisioned:** VPC · 2 subnets · 1 private route table (no default route) · security group  
**Not created:** IGW · NAT Gateway · EIP · public route table

---

### Scenario C — Mixed Public + Private with NAT Gateway

Public subnets serve internet-facing workloads (EKS load balancers, bastion hosts).
Private subnets host backend services and use a NAT Gateway for outbound internet
access (pulling container images, calling external APIs).

```yaml
global:
  create_network: true
  # nat_gateway_enabled: true   ← default, no need to set explicitly

  subnet_config:
    public-a:
      type: public
      availability_zone: "a"
      cidr_netnum: 101
    public-b:
      type: public
      availability_zone: "b"
      cidr_netnum: 102
    private-a:
      type: private
      availability_zone: "a"
      cidr_netnum: 201
    private-b:
      type: private
      availability_zone: "b"
      cidr_netnum: 202
```

**Resources provisioned:** VPC · IGW · 4 subnets · public route table
(`0.0.0.0/0 → IGW`) · private route table (`0.0.0.0/0 → NAT`) · Elastic IP ·
NAT Gateway · security group

> The NAT Gateway is placed in the **first public subnet** (key sorted alphabetically).
> All private subnets share one NAT Gateway.

---

### Scenario D — Bring Your Own VPC

Skip all VPC and subnet creation and point to existing infrastructure.

```yaml
global:
  create_network: false
  vpc_id: "vpc-0abc123456789"
  public_subnet_ids:
    - "subnet-0aaa111"
    - "subnet-0bbb222"
  private_subnet_ids:
    - "subnet-0ccc333"
    - "subnet-0ddd444"
```

**Resources provisioned:** none — existing VPC/subnet metadata is read via data sources.  
`subnet_config`, `vpc_cidr`, and `nat_gateway_enabled` are all ignored when `create_network: false`.

---

### `subnet_config` field reference

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | Yes | `"public"` or `"private"` |
| `availability_zone` | string | Yes | AZ suffix appended to `cloud_storage_region` (e.g. `"a"` → `ap-south-1a`) |
| `cidr_netnum` | number | Yes | Unique CIDR offset for `cidrsubnet()`. Must be unique across all entries |

### Optional top-level network keys

| Key | Default | Description |
|---|---|---|
| `create_network` | `true` | `true` = create VPC; `false` = use existing |
| `vpc_cidr` | `"10.0.0.0/16"` | CIDR block for the new VPC |
| `nat_gateway_enabled` | `true` | Create a NAT Gateway for private subnets. No effect if no private subnets are defined |
| `ingress_cidr_blocks` | `["0.0.0.0/0"]` | Source CIDRs allowed on HTTP (80) and HTTPS (443) inbound rules |

---

### What gets provisioned automatically

The module inspects `subnet_config` at plan time and creates only what is needed:

| Condition | Resources created |
|---|---|
| `create_network: true` | `aws_vpc` · `aws_security_group` |
| At least one `public` subnet | `aws_internet_gateway` · `aws_route_table` (public) · route table associations |
| At least one `private` subnet | `aws_route_table` (private) · route table associations |
| Private subnets **+** public subnet exists **+** `nat_gateway_enabled: true` | `aws_eip` · `aws_nat_gateway` · `0.0.0.0/0` route injected into private RT |
| Every subnet in `subnet_config` | `aws_subnet` (one per entry) |

---

## 2. Storage Module

### How it works

Define your S3 buckets under `global.buckets`. Each entry is a logical name
mapped to a `type` and optional feature flags.

The actual S3 bucket name is auto-generated as:

```
<building_block>-<environment>-<aws_account_id>-<logical_key>
```

Example with `building_block: "sunbird"`, `environment: "prod"`, account `123456789012`:

| Logical key | S3 bucket name |
|---|---|
| `public` | `sunbird-prod-123456789012-public` |
| `private` | `sunbird-prod-123456789012-private` |
| `dial` | `sunbird-prod-123456789012-dial` |
| `velero` | `sunbird-prod-123456789012-velero` |

---

### Scenario A — All Public Buckets

All buckets are publicly readable. CORS is applied per-bucket using `cors_enabled`.

```yaml
global:
  buckets:
    assets:
      type: public
      cors_enabled: true
    media:
      type: public
      cors_enabled: true
    content:
      type: public          # no CORS on this one
```

**Resources provisioned per bucket:** `aws_s3_bucket` · `aws_s3_bucket_public_access_block`
(all 4 flags set to `false`) · `aws_s3_bucket_policy` (public GetObject) ·
`aws_s3_bucket_cors_configuration` (only for `cors_enabled: true` entries)

---

### Scenario B — All Private Buckets

All buckets are fully blocked from public access. Versioning is applied per-bucket.

```yaml
global:
  buckets:
    configs:
      type: private
    backups:
      type: private
      versioning_enabled: true
    logs:
      type: private
      versioning_enabled: true
```

**Resources provisioned per bucket:** `aws_s3_bucket` · `aws_s3_bucket_public_access_block`
(all 4 flags set to `true`) · `aws_s3_bucket_versioning` (only for `versioning_enabled: true` entries)  
**Not created:** bucket policy · CORS configuration

---

### Scenario C — Mixed Public + Private

The default Sunbird deployment pattern — two core buckets plus optional extras.

```yaml
global:
  buckets:
    public:
      type: public
      cors_enabled: true
    private:
      type: private
      versioning_enabled: true
    dial:
      type: public
      cors_enabled: true
    velero:
      type: private
      versioning_enabled: true
```

OpenTofu evaluates each bucket independently and applies the correct access block,
bucket policy, CORS, and versioning based on the entry's own type and flags.

---

### `buckets` field reference

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | Yes | `"public"` or `"private"` |
| `cors_enabled` | bool | No (default `false`) | Attach a CORS rule. Uses `cors_max_age_seconds` for the `max-age` header |
| `versioning_enabled` | bool | No (default `false`) | Enable S3 object versioning |

### Optional top-level storage keys

| Key | Default | Description |
|---|---|---|
| `cors_max_age_seconds` | `3000` | Preflight cache duration (seconds) applied to all CORS-enabled buckets |

---

### What gets provisioned automatically

| Condition | Resources created |
|---|---|
| Every bucket | `aws_s3_bucket` · `aws_s3_bucket_public_access_block` |
| `type: public` | `aws_s3_bucket_policy` with `s3:GetObject` for `Principal: "*"` |
| `cors_enabled: true` | `aws_s3_bucket_cors_configuration` |
| `versioning_enabled: true` | `aws_s3_bucket_versioning` |

Public-access block flags by type:

| Flag | `type: public` | `type: private` |
|---|---|---|
| `block_public_acls` | `false` | `true` |
| `block_public_policy` | `false` | `true` |
| `ignore_public_acls` | `false` | `true` |
| `restrict_public_buckets` | `false` | `true` |

---

## 3. Full `global-values.yaml` Reference

Complete annotated reference for all network and storage configuration keys under `global:`.

```yaml
global:

  # ─── Identity ──────────────────────────────────────────────────────────────
  building_block: "sunbird"        # Prefix for all resource names and tags
  environment: "dev"               # Suffix for resource names (e.g. dev, staging, prod)
  cloud_storage_region: "ap-south-1"  # AWS region for all resources


  # ─── Network ───────────────────────────────────────────────────────────────

  create_network: true             # true = create VPC; false = use existing VPC below

  # Required only when create_network: false
  # vpc_id: "vpc-0abc123"
  # public_subnet_ids:
  #   - "subnet-0aaa111"
  #   - "subnet-0bbb222"
  # private_subnet_ids:
  #   - "subnet-0ccc333"
  #   - "subnet-0ddd444"

  vpc_cidr: "10.0.0.0/16"         # Optional. Default: 10.0.0.0/16
  nat_gateway_enabled: true        # Optional. Default: true. No effect without private subnets.
  ingress_cidr_blocks:             # Optional. Default: ["0.0.0.0/0"]
    - "0.0.0.0/0"

  subnet_config:
    # Each key is a logical name → tags, outputs, and remote state use this key.
    # S3 name formula: cidrsubnet(vpc_cidr, 8, cidr_netnum)
    # All cidr_netnum values must be unique across all entries.

    public-a:
      type: public                 # "public" or "private"
      availability_zone: "a"      # AZ suffix appended to cloud_storage_region
      cidr_netnum: 101             # → 10.0.101.0/24

    public-b:
      type: public
      availability_zone: "b"
      cidr_netnum: 102             # → 10.0.102.0/24

    # Uncomment to add private subnets. A NAT Gateway is auto-created.
    # private-a:
    #   type: private
    #   availability_zone: "a"
    #   cidr_netnum: 201           # → 10.0.201.0/24
    # private-b:
    #   type: private
    #   availability_zone: "b"
    #   cidr_netnum: 202           # → 10.0.202.0/24


  # ─── Storage ───────────────────────────────────────────────────────────────

  cors_max_age_seconds: 3000       # Optional. Default: 3000. Applies to all cors_enabled buckets.

  buckets:
    # Each key is a logical name.
    # Bucket name formula: <building_block>-<environment>-<account_id>-<key>
    # type: "public"  → publicly readable, no versioning by default
    # type: "private" → fully access-blocked, no public policy

    public:
      type: public
      cors_enabled: true           # Optional. Default: false

    private:
      type: private
      versioning_enabled: true     # Optional. Default: false

    # Add more buckets as needed:
    # dial:
    #   type: public
    #   cors_enabled: true
    # velero:
    #   type: private
    #   versioning_enabled: true
    # my-custom-bucket:
    #   type: private
    #   versioning_enabled: true
```

---

## 4. Module Outputs Reference

### Network module

| Output | Description |
|---|---|
| `vpc_id` | VPC ID (created or existing) |
| `vpc_cidr_block` | VPC CIDR block |
| `subnets` | Map of all subnets keyed by logical name: `{ id, arn, cidr_block, availability_zone, type }` |
| `public_subnet_ids` | Flat list of public subnet IDs (used by EKS module) |
| `private_subnet_ids` | Flat list of private subnet IDs |
| `internet_gateway_id` | IGW ID, or `null` if no public subnets |
| `nat_gateway_id` | NAT GW ID, or `null` if not created |
| `nat_gateway_public_ip` | Elastic IP of the NAT GW, or `null` if not created |
| `public_route_table_id` | Public route table ID, or `null` if no public subnets |
| `private_route_table_id` | Private route table ID, or `null` if no private subnets |
| `security_group_id` | HTTP/HTTPS security group ID |

### Storage module

| Output | Description |
|---|---|
| `buckets` | Map of all buckets keyed by logical name: `{ id, arn, domain, type }` |
| `storage_bucket_public` | Name of the bucket with key `public` (`null` if not in `buckets`) |
| `storage_bucket_public_arn` | ARN of the `public` bucket |
| `storage_bucket_public_domain` | Regional domain of the `public` bucket |
| `storage_bucket_private` | Name of the bucket with key `private` (`null` if not in `buckets`) |
| `storage_bucket_private_arn` | ARN of the `private` bucket |
| `dial_bucket` | Name of the bucket with key `dial` (`null` if not in `buckets`) |
| `dial_bucket_arn` | ARN of the `dial` bucket |
| `velero_bucket` | Name of the bucket with key `velero` (`null` if not in `buckets`) |
| `velero_bucket_arn` | ARN of the `velero` bucket |

> The named convenience outputs (`storage_bucket_public`, `dial_bucket`, etc.) exist
> for backward compatibility with the IAM and output-file modules. They return `null`
> if the corresponding key is absent from `var.buckets`. The generic `buckets` output
> always reflects exactly what was provisioned and is the recommended output for
> new consumers.
