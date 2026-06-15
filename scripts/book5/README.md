# book5 scripts

Backup copies of custom scripts that live on `prox-book5` but outside any package — keep them here so `push-all` backs them up and a rebuild can restore them.

## 90-twingate-dns-pin — NetworkManager dispatcher hook

**Deploy path:** `/etc/NetworkManager/dispatcher.d/90-twingate-dns-pin`
**Owner/perms:** `root:root`, `0755` (NM refuses to run dispatcher scripts that are group/other-writable)
**Deployed:** 2026-05-27

### Problem it solves

The book5 Twingate connector (`prox-book5-systemd`) periodically went `DEAD_HEARTBEAT_TOO_OLD`
in the TG admin console while `systemctl is-active twingate-connector` still said `active`.

Root cause: a Twingate client update **deletes and recreates** the `sdwan0` NetworkManager
connection (fresh UUID) with Twingate's own `100.95.0.x` resolvers and `ipv4.ignore-auto-dns=no`.
Those resolvers go dead while the client still reports `online`, so **all** book5 DNS times out,
the connector can't reach the control plane, and the heartbeat dies. The connector process is
healthy — only DNS is broken.

Manual `nmcli connection modify sdwan0 ipv4.dns 192.168.68.248 …` did NOT hold, because the
delete+recreate wipes the persisted `.nmconnection` profile each time. Recurred 3x by 2026-05-27.

### What the hook does

On every `sdwan0` `up` / `dhcp4-change` / `dhcp6-change` event, if the DNS is not already
pihole (`192.168.68.248`) with `ignore-auto-dns=yes`, it re-pins DNS, reapplies the connection,
and restarts `twingate-connector`. A guard makes it a no-op once DNS is correct, so the reapply it
triggers does not loop. The delete+recreate fires a real `up` event, which is the hook's trigger —
so it self-heals within seconds of each TG revert.

Note: `nmcli device reapply` alone does NOT fire a dispatcher event (it's `device-reapply`, not
`up`). Only a connection delete+recreate or a down/up does. Test with `nmcli connection up sdwan0`,
not a bare reapply.

### Redeploy after a rebuild

```bash
scp scripts/book5/90-twingate-dns-pin book5:/etc/NetworkManager/dispatcher.d/90-twingate-dns-pin
ssh book5 'chown root:root /etc/NetworkManager/dispatcher.d/90-twingate-dns-pin \
  && chmod 0755 /etc/NetworkManager/dispatcher.d/90-twingate-dns-pin'
```

### Verify

```bash
# trigger a real up event with the DNS currently wrong, watch it self-heal
ssh book5 'nmcli connection up sdwan0; sleep 3; grep -m1 nameserver /etc/resolv.conf'
ssh book5 'journalctl -t twingate-dns-pin --no-pager --since "5 min ago"'

# connector state from the TG admin API (token in macOS Keychain)
TG=$(security find-generic-password -a twingate -s twingate-api -w)
curl -s -X POST https://jaded423.twingate.com/api/graphql/ \
  -H "X-API-KEY: $TG" -H "Content-Type: application/json" \
  -d '{"query":"{ connectors(first:50){edges{node{name state lastHeartbeatAt}}}}"}'
```

Canonical context: `~/.claude/CLAUDE.md` "book5 DNS routing" note; `docs/network-cleanup-todo.md`.
