# Fleet Index Service (FIS) — Design Research

> Pre-executor research notes for the Fleet Index Service. Captures the
> authority model, normative invariants, and open brainstorming. Not yet
> the faithful-rebuild spec — that lands in `../executor/` once this
> converges. Migrated from `gridworks-infra/authority/fleet-index-service/`.

## Purpose

Enforces single authorized GNodeInstanceId per GNodeId.

Proposed start: Lease-based single-writer authority model where a GNode can have at most one live instance and a new instance implicitly supersedes old one.

## Scope

 - Tracks active instances
 - Determines authoritative instance
 - Exposes RabbitMQ HTTP authentication endpoints:
    - `/auth/user`
    - `/auth/vhost`
    - `/auth/resource`


/auth/vhost
 - Check if GNode allowed to access given vhost
 - For v1: always allow /

/auth/resource
 - Check publish/consume permissions
 - For v1: allow all


## Authority Guarantees

Explicitly define:

At most one authoritative instance per GNodeId at any point in time


## Invariants (Normative)

1. **Single Writer**
   - For each `GNodeId`, at most one `GNodeInstanceId` SHALL be authorized at any time.

2. **Explicit Authority**
   - Operational publish rights SHALL NOT be inferred from naming conventions or network location.
   - Authority SHALL be granted explicitly via FIS.

3. **Separation of Identity and Instance**
   - mTLS SHALL authenticate durable node identity `GNodeId`.
   - FIS SHALL authorize the active runtime instance (`GNodeInstanceId`).

4. **Broker Enforcement**
   - The broker SHALL enforce that only the authorized `GNodeInstanceId` may publish operational messages for a given `GNodeId`.

## VARIOUS BRAINSTORMING


### `/validate` Endpoint Implementation: 
**Case 1 Malformed query**
return **REJECTED**


**Case 2 InstanceId already exists in DB**

Then:
 - If associated with same GNodeId:
   - If marked active → AUTHORIZED (idempotent reconnect)
   - If marked revoked → NOT_AUTHORIZED
 - If associated with different GNodeId:
  - NOT_AUTHORIZED (security violation)

**Case 3 InstanceId Never Seen Before**

Verify claims
  1. Verify GNode Exists  (look up `g.node.gt` in registry by `GNodeId`)
  2. Verify GNode Status 
  3. Verify Alias. Check:  `registry.Alias == claimed_alias`
  4. Verify Class. Check registry.GNodeClass == claimed_class
  5. Verify InstanceId structure

registry.GNodeClass == claimed_class
registry.BaseClass == claimed_base_class

Create record:
 - Associate InstanceId with GNodeId
 - Mark as ACTIVE
If another instance is ACTIVE for same GNodeId:
  - Mark previous instance as REVOKED
  - Close its connection via Rabbit API
Return AUTHORIZED


Map:
  - AUTHORIZED → {"result": "allow"}
  - NOT_AUTHORIZED → {"result": "deny"}
  - REJECTED → {"result": "deny"}


After returning, publish auth event aysnchronously. Something like:
```
{
  "EventId": "4e5a6b1c-2d3e-4f5a-8b9c-1d2e3f4a5b6c",
  "GNodeId": "9cff2689-eadc-4577-94ea-6d86d0d23e9e",
  "GNodeAlias": "d1.isone.me.versant.keene.beech.scada",
  "GNodeInstanceId": "b6d86d0d-23e9-4c3d-8123-89c71f6a21bc",
  "Decision": "Authorized",
  "Reason": "NewInstanceSupersedesPrevious",
  "DecidedAtUnixS": 1771979700,
  "TypeName": "runtime.instance.authorization",
  "Version": "000"
}
```


### Rabbit config
Configure rabbit with:
```
auth_mechanisms.1 = external
auth_backends.1 = http
auth_http.user_path = http://fis:8080/auth/user
auth_http.vhost_path = http://fis:8080/auth/vhost
auth_http.resource_path = http://fis:8080/auth/resource

```
and enable plugin rabbit_auth_backend_http


notes also re mTLS:

```
listeners.ssl.default = 5671

ssl_options.cacertfile = /etc/rabbitmq/ca.pem
ssl_options.certfile   = /etc/rabbitmq/server_cert.pem
ssl_options.keyfile    = /etc/rabbitmq/server_key.pem

ssl_options.verify = verify_peer
ssl_options.fail_if_no_peer_cert = true
ssl_options.ciphers.1 = ECDHE-ECDSA-AES256-GCM-SHA384
ssl_options.ciphers.2 = ECDHE-RSA-AES256-GCM-SHA384

loopback_users.guest = false
```
and remove guest

### Publishing Operational Messages (Normal Operation)

Once authorized and broker-enforced, SCADA may publish operational messages.

Include in the messages themselves:
- `FromGNodeAlias` 
- `MessageCreatedMs` (or equivalent)

FOR LATER 
and in the message envelope
- `FromGNodeInstanceId`
- `FromGNodeId`

for audit trail 

DOES NOT NEED TO HAPPEN RIGHT AWAY (requires proactor change)

### Manual Broker Revocation

- New instance registers with FIS
- FIS marks old instance unauthorized
- FIS calls Rabbit Management API 
  - Queries rabbit to list connection
  - filters by username (GNodeId)
  - identifies the specific connection
  - calls:
```
DELETE /api/connections/<id>
```
- rabbit immediately closes socket
- FIS marks new instance authorized


### SCADA Shutdown

Shutdown types:
1. **Clean shutdown**
   - SCADA notifies FIS: instance is ending
   - FIS clears authorization (or marks ended)
2. **Crash / power loss**
   - No notification
   - Authorization ends through revocation

### FIS db structure

grid node registry emits messages on change
FIS consumes these and populates its own g_node table
keeping a strict bijection between g.node.gt and the g_node table (no position_point table or foreign key though)

---
### Test speed
Before rolling to fleet:

Test:
 - Valid cert
 - Revoked instance
 - Suspended GNode
 - Wrong alias claim
 - Two instances racing
 - Measure FIS latency under 100 concurrent connects

Auth must be fast.
