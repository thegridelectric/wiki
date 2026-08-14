# Day in the Life of a SCADA Runtime Instance

Status: Draft · Pass 0 · Updated 2026-08-14

> Research (pre-spec). The normative contract is
> [`../executor/primary.md`](../executor/primary.md); this walks one
> concrete boot. The SCADA speaks MQTT; the AMQP variant differs only in
> how the claims travel (the `claims` sema word via the GridWorks SASL
> mechanism, instead of `client_id`).

## Pre-condition

SCADA device has:

- Correct GNode data on disk, e.g.

```
{
  "GNodeId": "9cff2689-eadc-4577-94ea-6d86d0d23e9e",
  "Alias": "d1.isone.me.versant.keene.beech.scada",
  "BaseClass": "Logical",
  "GNodeClass": "Scada",
  "Status": "Active",
  "TypeName": "g.node.gt",
  "Version": "004"
}
```

- A valid mTLS client certificate for the broker, **Cert CN = GNodeId**
- Access to the broker endpoint (MQTTS 8883)
- Local clock sufficiently accurate for timestamps (NTP or equivalent)

## Steps

1. SCADA boots and generates a new `GNodeInstanceId` UUID.
2. SCADA connects with MQTT over TLS, presenting its client cert, with
   **`client_id = GNodeInstanceId`**. (No client_properties — MQTT has
   none, and they never reach auth backends anyway.)
3. RabbitMQ completes the TLS handshake (cert validated against the
   GridWorks CA) and derives **`username = GNodeId`** from the cert CN
   (`mqtt.ssl_cert_login`). No password is sent; an explicit
   username/password would *override* the cert name and is denied (no
   fleet password users exist).
4. Rabbit calls FIS:

```
POST /auth/user
{
  "username": "9cff2689-eadc-4577-94ea-6d86d0d23e9e",
  "client_id": "b6d86d0d-23e9-4c3d-8123-89c71f6a21bc",
  "vhost": "hw1__1"
}
```

5. FIS: principal active? instance id vs the (identity, run) lease —
   reconnect → allow; revoked → deny; new → supersede synchronously
   (revoke prior lease, close its connections via the management API,
   confirm none remain — an empty kill is success), then allow.
6. Connection accepted. FIS publishes the
   `fis.instance.authorization.event` asynchronously.
7. First publish on each routing key triggers `/auth/topic` (write):
   segment 2 must equal the registry's current alias for this GNodeId —
   a stale-alias node connects but cannot publish, which is the rename
   backstop. Subscribes (`/auth/topic` read) are allowed.
