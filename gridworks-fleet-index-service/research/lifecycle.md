# Day in the Life of a SCADA Runtime Instance


## Pre-condition: 
SCADA device has
- Correct GNode data, e.g.

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
- A valid mTLS client certificate for rabbit broker where Cert CN = GNodeId
- Local clock sufficiently accurate for timestamps (NTP or equivalent)

The SCADA device has:
- Access to broker endpoint(s)
- A valid mTLS client certificate
  - assume Cert CN = GNodeId

### Steps

1. SCADA boots and generates a new `GNodeInstanceId` UUID. 


2. SCADA runtime connects to RabbitMQ, and includes  GNodeInstanceId and GNodeAlias, GNodeClass in  AMQP `client_properties`.
```
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host=...,
        port=...,
        ssl_options=...,
        credentials=...,
        client_properties={
            "g_node_alias": "<str>"
            "g_node_instance_id": "<uuid>",
            "g_node_class": "<str>"
        }
    )
)
```
3. RabbitMQ does the TLS handshake (certificate validation)
  - derives `username` (which is `GNodeId`) from cert CN


4. Rabbit calls FIS `/auth/user`
```
POST /auth/user
{
  "username": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "client_properties": {
      "g_node_instance_id": "9cff2689-eadc-4577-94ea-6d86d0d23e9e",
      "g_node_alias": "hw1.isone.me.keene.beech.scada",
      "g_node_class": "Scada",
  },
  "vhost": "/",
  "ip": "100.72.14.3"
}

```

5. FIS:
  - verifies GNode exists + Active
  - verifies claims (e.g. has matching class and alias)
  - creates instance record if new
  - revokes old instance if needed

6. FIS returns AUTHORIZED
7. Connection accepted


