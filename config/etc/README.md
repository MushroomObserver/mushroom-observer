# config/etc — deployed-infrastructure copies of record

Files in this directory are **not** executed or loaded from the repo
checkout. Each one is the checked-in copy of record for a piece of
system configuration that is deployed by hand to its real location on
one of MO's machines. They live here so that infrastructure changes get
the same review, history, and searchability as application code — and
so audits can read what production is (supposed to be) running without
logging into a server (see issue #4859 for a case where a server-only
script's behavior took an afternoon of forensics to reconstruct).

Two rules:

1. **When you change a file here, deploy it; when you change the
   deployed copy, backport it here.** Nothing syncs these
   automatically, and a divergent repo copy is worse than none — it
   reads as authoritative and isn't.
2. **New server-side config belongs here, not only on the server.**
   `rclone_originals.sh` lived solely on the images server for years;
   its once-only-archival design flaw stayed invisible until #4859.

## Where each file goes

| File | Machine | Deployed location / how |
|---|---|---|
| `crontab` | web server | `mo`'s crontab (`crontab config/etc/crontab` as `mo`) |
| `nginx.conf` | web server | `/etc/nginx/nginx.conf` |
| `nginx_dev.conf` | local dev | nginx config for a dev setup |
| `puma.service` | web server | `/etc/systemd/system/puma.service` |
| `solidqueue.service` | web server | `/etc/systemd/system/solidqueue.service` |
| `rclone_originals.sh` | images server | `/data/images/mo/rclone/rclone_originals.sh`, run by `mo`'s crontab there (`15 1 * * *`) — nightly originals→GCS archive sync |
| `bash_aliases.sh` | web server | sourced from `mo`'s shell profile |
| `no-reply.forward` | web server | `~no-reply/.forward` — pipes mail to the autoreply |
| `no-reply.autoreply` | web server | autoreply body sent for mail to no-reply@ |
| `no-reply.muttrc` | web server | `~no-reply/.muttrc` for the autoreply pipeline |
| `indexmaker` | web server | MRTG 2.17.4 index generator (traffic-graph pages) |
| `unicorn` | — | obsolete init script from the pre-puma era; kept for history |

If a location above is wrong or has drifted, fix the table — it is only
as useful as it is accurate.
