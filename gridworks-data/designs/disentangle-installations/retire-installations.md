# retire-installations — the tables leave journaldb

Status: Accepted · Pass 1 · Updated 2026-10-15 · Linear: OPS-473

> What this is: the second spoke of the disentangle-installations hub.
> `installations`, `customers` and `installers` are dropped from
> journaldb outright; roles re-key to the TA GNodeId; web-backend and
> the frontend keep working with the Address and Contact sections dark
> until OPS-600.

## Do this next

Branch `jm/retire-installations` in gridworks-data, gridworks-web-backend
and gridworks-web-frontend. In gridworks-data: delete the three models
and the seed script's use of them, re-key `user_installation_roles` to a
plain `ta_g_node_id` column, write the alembic migration. gjk does not
reference the tables (checked 2026-10-15); it stays on `main`.

## What survives, and where each field goes

- **The house list** is the TerminalAsset rows of the `g_nodes`
  projection; `display_name` comes from gnr, which owns it as mutable
  presentation.
- **Roles** key on the TA GNodeId as a plain column, no foreign key; a
  null still means every house. Forced into this spoke by the foreign
  key to `installations.id`. The table itself moves to web-backend's
  identity database under OPS-600.
- **The Hardware section** reads the latest `layout.lite` from the
  journal messages through the codec.
- **address, customers, installers** are in gridworks-pii (pii-store),
  seeded before this spoke drops them; latitude and longitude are
  deleted.
- **hardware_layout, house_parameters, representation_status,
  alert_status, scada_ip_address, scada_git_commit** are deleted, not
  migrated. The words in the journal are the truth for the first two;
  the fleet drift check already knows the commit every box runs; alert
  state belongs to the alerting rework.

## Web-backend

Eight files reference the table (checked 2026-10-15): `backend_api.py`,
`v2/shared_queries.py`, `v2/dependencies.py`, and the routers
`installation_summaries`, `alerts`, `hourly_data_download`, `messages`,
`readings_csv`, `flo_download`, `hourly_electricity`. Most use it as the
join for the house list; those move to the `g_nodes` projection. The v2
summaries endpoint stops returning `primary_contact`,
`secondary_contact`, `address` and `house_parameters`; its layout string
comes from `layout.lite`. The v1 login path's use of `installations` is
removed with the rest, the login itself is untouched here.

## Frontend

The Information page keeps its four sections. Address and Contact render
"not shown" until OPS-600; Status and Hardware keep working. The
house picker and the data-export pages read the house list from the new
endpoint shape.

## Cutover

1. pii-store is seeded and verified (six customers, labels, no
   coordinates).
2. gridworks-data migration applied to journaldb; web-backend and
   frontend deployed from the branches in the same window.
3. Row-level check: the dashboard lists six houses, every Status and
   Hardware section renders, no endpoint returns a contact or address.
4. Operators look customers up with the CLI from here until
   OPS-600.

## Open

- Whether operational params are published on the bus the way
  `layout.lite` is. If not, the Status section may lose a field; find
  the reader before step 2.
