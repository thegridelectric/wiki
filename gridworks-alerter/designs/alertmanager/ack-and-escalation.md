# ack-and-escalation — acknowledge from Telegram, escalate by phone, rotate from the sheet

Status: Draft · Pass 0 · Updated 2026-09-30

> **What this is.** Spoke 4 of the alertmanager design: the three
> people-facing behaviours the hand-written manager had and Alertmanager
> does not, rebuilt as small services hanging off Alertmanager's API and
> receivers rather than inside it. Taken up after spoke 2 has
> Alertmanager paging on the box; sized here so it is not re-derived.

## Acknowledge

Alertmanager has no acknowledgement; a **silence on the alert's labels
is the acknowledgement**, and everything below treats it that way. The
manager's 👍 on the Telegram message stays the gesture. A small bot
registers a Telegram webhook on one route behind the box's Caddy face
(the box already has the public HTTPS front), receives each
`message_reaction` as it happens, maps the reacted message back to the
alert it announced, and creates the silence through Alertmanager's API.
👎 is the same silence with a longer expiry (the manager's
mute-for-the-day). No polling loop: the manager's 30 s short-poll of
`getUpdates` is the thing this replaces. Reaction updates reach a bot in
a group only when the bot is a group admin, so the receiver groups make
the bot admin. About half a day.

## Escalate

Alertmanager cannot escalate on "unacknowledged", because it has no
acknowledgement. A webhook receiver on the firing route feeds a small
escalation service: on each firing notification it waits the escalation
delay, asks Alertmanager whether the alert is still active and
unsilenced, and if so places a Telnyx call with a spoken summary
(`house`, `summary` annotations) to the on-call number. A silence,
which is the ack above, is what stops the call. About a day including
the Telnyx account and number.

## Rotate

The Google Sheet stays the human-readable schedule (who, which weekday,
which hours). A generator reads it and writes Alertmanager
`time_intervals` plus one route per person into the committed
`alertmanager.yml`; a schedule change is run the generator, commit,
copy, `amtool check-config`, reload. A few hours. Until it exists, one
Telegram group per route is the rotation.

## Do this next

Nothing until spoke 2 pages from the box. Then: the ack bot first (it
is what makes escalation meaningful), escalation second, the generator
when the group-per-route rotation stops being enough.
