# Traefik Ingress → Kubernetes Gateway API Migration Plan

> **Repo:** `fluxcd` GitOps repo · **Date:** 2026-07-30
> **Scope:** Migrate all HTTP(S) routing from `networking.k8s.io/v1` Ingress (Traefik provider) to Gateway API (`gateway.networking.k8s.io/v1`), keeping Traefik as the implementation.
> **Strategy:** Incremental, per-app, zero-downtime. Both providers run side by side on the same Traefik instance and the same kube-vip LoadBalancer IP — **no DNS changes are required at any point.**

---

## 1. Current state (inventory summary)

### Routing resources (25 total)

| Kind | Count | Notes |
|---|---|---|
| Ingress (standalone files) | 19 | All identical pattern: `ingressClassName: traefik` (2 missing it — navidrome), `router.entrypoints: websecure`, `cert-manager.io/cluster-issuer: letsencrypt-prod`, per-host TLS secret |
| Ingress (embedded in HelmRelease values) | 5 | grafana (operator CR), jaeger, prometheus, alertmanager, harbor + traefik-dashboard via `extraObjects` |
| IngressRouteTCP | 1 | `openshell` — TLS **passthrough** via `HostSNI`, cannot become an HTTPRoute |
| Middleware / TLSOption / TLSStore / ServersTransport | 0 | **Nothing to convert** — no middleware annotations exist anywhere |

### Key infrastructure facts

- **Traefik:** helm chart **39.0.8** (v3.x), DaemonSet in `networking`, entrypoints `web` (container port 8000, global HTTP→HTTPS redirect) and `websecure` (container port **8443**, exposed as 443, `readTimeout: 360s`). Providers `kubernetesCRD` + `kubernetesIngress` enabled. LB Service gets its IP via kube-vip DHCP (`kube-vip.io/hwaddr`).
- **cert-manager:** v1.20.2 in `auth`, single ClusterIssuer `letsencrypt-prod` with **DNS-01 via Cloudflare**. All certs are auto-created per-Ingress via annotation; no explicit `Certificate` CRs, no wildcards. Harbor uses a pre-provisioned `traunseenet-cert` secret.
- **external-dns:** v0.20.0, rfc2136 → Technitium. **`gateway-httproute` and `gateway-grpcroute` sources are already enabled** in the deployment args (`gateway-tlsroute`/`tcproute`/`udproute` commented out: "CRD not installed").
- **Flux dependency chain:** `kubevip-app → cert-manager-base → cert-manager-addons → traefik-base → <all apps>` — every ingress-bearing app already has `dependsOn: traefik-base`.
- **Domain tiers:** `*.cloud.traunseenet.com` (LAN via kube-vip LB), `*.web.traunseenet.com` (internet via newt/Pangolin tunnel — still terminates at Traefik in-cluster), `longhorn.local.traunseenet.com`, plus `api.s3.cloud.traunseenet.com` (⚠ two labels deep — see §4.3).

### Research conclusions that shape this plan

| Finding | Consequence |
|---|---|
| Traefik v3.7.x (chart **v41.1.0**) supports Gateway API v1.5.1, conformant; v3.7.0 fixed multiple-certificateRef and hostname/cert-selection bugs (#11972, #12742) | **Upgrade the chart before enabling the provider.** Do not attempt Gateway API on chart 39.x |
| Gateway API **v1.6.1** is current; TCPRoute/UDPRoute went GA in v1.6.0 (standard channel) | Install standard-channel CRDs, pinned to v1.6.1 |
| Traefik chart does **not** install Gateway API CRDs | CRDs need their own Flux Kustomization, `prune: false` |
| Both providers (`kubernetesIngress` + `kubernetesGateway`) run simultaneously; routers are merged | Per-app migration with instant rollback (re-add the Ingress) |
| Gateway listener `port` must equal the **entrypoint container port** (8000/8443), not the Service port (80/443) | Listeners use `8443`; a mismatch = listener silently ignored (ERROR log) |
| HTTPRoute `spec.timeouts` is **not implemented** by Traefik (issue #11902) | The 360s `readTimeout` stays at entrypoint level — no change needed, but no per-route override either (relevant for Immich/Paperless uploads) |
| Traefik bug #13247: `backendRef.port: 443` is assumed to be TLS | No backend here uses 443 — not affected |
| HTTPRoute `backendRefs[].port` must be a **numeric port** | Ingresses using named ports (`http`, `web`, `http-tcp`…) need the real port number looked up from the Service |
| cert-manager Gateway support exists, but with explicit `Certificate` CRs + DNS-01 it is **not needed** | Simplest path: wildcard `Certificate` CRs in `networking`, no cert-manager config change |
| external-dns picks up `spec.hostnames` from HTTPRoutes; targets come from Gateway `status.addresses` | Set `providers.kubernetesGateway.statusAddress.service` so the Gateway status carries the Traefik LB IP |
| ingress2gateway v1.2.0 has a Traefik provider, but only converts the entrypoints/TLS annotations | Optional here — the Ingresses are so uniform that a hand-written HTTPRoute template is cleaner (§5.2) |

---

## 2. Target architecture

```
                          ┌────────────────────────────────────────────┐
 internet ── newt tunnel ─┤  Traefik DaemonSet (networking ns)         │
 LAN ─── kube-vip LB IP ──┤  entrypoints: web :8000 → redirect         │
                          │              websecure :8443 (TLS, 360s)   │
                          │  providers: kubernetesGateway (+CRD)       │
                          └───────────────┬────────────────────────────┘
                                          │ implements
                          GatewayClass "traefik" (chart-managed)
                                          │
                          Gateway "traefik" (networking ns, GitOps-managed)
                          ├─ websecure-cloud  *.cloud.traunseenet.com   (wildcard cert)
                          ├─ websecure-web    *.web.traunseenet.com     (wildcard cert)
                          ├─ websecure-local  *.local.traunseenet.com   (wildcard cert)
                          └─ websecure-s3     api.s3.cloud.traunseenet.com (dedicated cert)
                                          ▲
                     HTTPRoute per app (in the app's namespace, next to its Deployment)
                     parentRefs → networking/traefik + sectionName
```

**Design decisions (and why):**

1. **One shared Gateway in `networking`, one HTTPS listener per domain tier, wildcard certs.** This is the converged homelab/GitOps community pattern. It replaces ~23 per-host certificates with 4, sidesteps the Traefik multiple-certificateRefs-per-listener bug class entirely (one certRef per listener), and removes the need for cert-manager's Gateway integration.
   *Alternative (rejected): keep per-host certs → would require one listener per hostname (~23 listeners) or rely on recently-fixed cert-selection code.*
2. **Gateway defined as a plain manifest in a new `traefik/addons` Kustomization**, not via the chart's `gateway.*` values — multiple listeners across domains are clearer as YAML we own, and the chart-created Gateway is disabled (`gateway.enabled: false`). The chart still manages the **GatewayClass**.
3. **No HTTP listener on the Gateway.** The existing entrypoint-level HTTP→HTTPS redirect (`ports.web.http.redirections`) is static config and fires before any routing — it keeps working for Gateway API traffic. No per-app redirect HTTPRoutes needed. (DNS-01 means no HTTP-01/ACME need for port 80 either.)
4. **Explicit wildcard `Certificate` CRs** instead of the `cert-manager.io/cluster-issuer` annotation on the Gateway — GitOps-explicit, works with cert-manager as-is (no `config.enableGatewayAPI` required), secrets land in `networking` next to the Gateway (no ReferenceGrant needed).
5. **OpenShell stays on IngressRouteTCP** for now (TLS passthrough). Optional later migration to TLSRoute in §7.
6. **`allowedRoutes.namespaces.from: All`** on all listeners — single-admin homelab; tighten to a label selector later if desired.

---

## 3. Phase 0 — Preparation (no Gateway API yet)

**Goal:** get onto a Traefik version whose Gateway API provider is trustworthy, while still Ingress-only. Isolating the chart upgrade from the provider change keeps failure domains separate.

1. **Upgrade the Traefik chart** in `kubernetes/apps/networking/traefik/traefik/base/release.yaml`:
   `version: 39.0.8` → `version: 41.1.0` (Traefik v3.7.9).
   Read the chart 40.x/41.x release notes for values renames before bumping. Verify all existing Ingresses still route afterwards.
2. **Verify cluster CRD state:** `kubectl get crd | grep gateway.networking` — external-dns already has gateway sources enabled, which suggests the CRDs may already exist on the cluster out-of-band. If they do, note the version; the Flux-managed install in Phase 1 must be applied server-side to take over field ownership.
3. **Verify external-dns RBAC** includes Gateway API resources (`gateways`, `httproutes` get/list/watch in its ClusterRole in `kubernetes/apps/networking/external-dns/external-dns/app/`). Add them if missing — the sources are enabled but will silently fail without RBAC.
4. **Record current state for rollback/diffing:**
   ```bash
   kubectl get ingress -A -o wide > /tmp/pre-migration-ingresses.txt
   kubectl get certificate -A > /tmp/pre-migration-certs.txt
   ```

**Verification gate:** all apps reachable, `flux get ks -A` all Ready, Traefik logs clean.

### Phase 0 findings (2026-07-31 pre-flight, via Bifrost/kubernetes-mcp)

- Cluster was already on chart **39.0.9** (Traefik v3.6.15, Renovate bump 2026-07-30), HelmRelease Ready.
- **Gateway API CRDs are already installed** — chart v39.x bundles `gateway-standard-install.yaml` (**Gateway API v1.4.0 standard channel**), applied at initial install in April. Chart **v41 no longer ships them** (issue #1669), so the chart upgrade leaves them untouched and Phase 1's Flux-managed v1.6.1 install is a clean SSA takeover/upgrade.
- Chart 39→41 breaking changes affecting this repo: only `service.type` → `service.spec.type` (v40, PR #1686 — the old key would be silently ignored and the Service would fall back to ClusterIP). v41's `logs.*`/file-provider renames don't apply here (log level is set via CLI arg).
- Added `crds: CreateReplace` to install/upgrade in the HelmRelease so `traefik.io` CRDs get the v3.7 updates (helm skips bundled CRDs on upgrade by default). Safe because v41 no longer bundles Gateway API CRDs.
- external-dns ClusterRole already grants get/list/watch on `gateways`, `httproutes`, `grpcroutes` — step 3 passes as-is (`tlsroutes` still commented out; only needed for optional Phase 4).
- kubernetes-mcp SA (`view` + flux extras) had no read access to Gateway API resources or CRDs; extended `kubernetes-mcp-extras` ClusterRole with read on CRDs, `gateway.networking.k8s.io/*`, and `traefik.io/*` for migration verification via Bifrost.
- Pre-migration snapshot: git is the source of truth for all routing resources (inventoried in §1); no kubectl dump taken (no local kubeconfig — cluster access is via Bifrost only).

---

## 4. Phase 1 — Foundation (CRDs, provider, Gateway, certs)

### 4.1 Gateway API CRDs via Flux

New source in `kubernetes/flux/repositories/` (`git/gateway-api.yaml`):

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: gateway-api
  namespace: flux-system
spec:
  interval: 12h
  url: https://github.com/kubernetes-sigs/gateway-api
  ref:
    tag: v1.6.1
  ignore: |
    /*
    !/config/crd
```

New Kustomization — `kubernetes/apps/networking/gateway-api/ks.yaml` (wired into `kubernetes/apps/networking/kustomization.yaml` like the other networking apps):

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: gateway-api-crds
  namespace: flux-system
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: gateway-api
  path: ./config/crd/standard
  prune: false        # NEVER prune CRDs — deleting them deletes every Gateway/HTTPRoute
  wait: true          # block dependents until CRDs are Established
```

> Standard channel is sufficient: HTTPRoute, GRPCRoute, TLSRoute, ReferenceGrant, and (since v1.6.0) TCPRoute are all in it. The experimental channel is only needed for UDPRoute, which Traefik doesn't implement anyway.
>
> *Alternative:* vendor `standard-install.yaml` into the repo for an air-gapped reconcile. GitRepository + pinned tag is preferred here — upgrades are a one-line tag bump.

**Dependency wiring:** add to `kubernetes/apps/networking/traefik/traefik/ks.yaml` (`traefik-base`):

```yaml
  dependsOn:
    - name: cert-manager-addons   # existing
    - name: kubevip-app           # existing
    - name: gateway-api-crds      # new
```

Apps already depend on `traefik-base`, so the whole chain stays ordered.

### 4.2 Traefik HelmRelease: enable the Gateway provider

In `traefik/base/release.yaml` values (diff against current):

```yaml
    providers:
      kubernetesCRD:                      # unchanged — still needed for
        enabled: true                     # IngressRouteTCP (openshell) and any
        ingressClass: traefik             # future ExtensionRef middlewares
        allowExternalNameServices: true
      kubernetesIngress:                  # unchanged — keep until Phase 4
        enabled: true
        allowExternalNameServices: true
        publishedService:
          enabled: true
          pathOverride: "networking/traefik"
      kubernetesGateway:                  # NEW
        enabled: true
        experimentalChannel: false
        statusAddress:
          service:                        # publishes the LB IP into
            name: traefik                 # Gateway status.addresses →
            namespace: networking         # external-dns uses it as DNS target
    gateway:
      enabled: false                      # NEW — we manage our own Gateway (§4.4)
    gatewayClass:
      enabled: true                       # NEW — chart creates GatewayClass "traefik"
      name: traefik
```

Everything else (DaemonSet, entrypoints, kube-vip annotations, redirect, timeouts, tracing) stays exactly as is. **The same LB Service and IP serve both providers.**

### 4.3 Wildcard certificates

New file `traefik/addons/certificates.yaml` (namespace `networking`):

```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-cloud-traunseenet
  namespace: networking
spec:
  secretName: wildcard-cloud-traunseenet-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.cloud.traunseenet.com"
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-web-traunseenet
  namespace: networking
spec:
  secretName: wildcard-web-traunseenet-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.web.traunseenet.com"
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-local-traunseenet
  namespace: networking
spec:
  secretName: wildcard-local-traunseenet-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.local.traunseenet.com"
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: s3-api-cloud-traunseenet
  namespace: networking
spec:
  secretName: s3-api-cloud-traunseenet-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "api.s3.cloud.traunseenet.com"
```

> ⚠ **Why the 4th cert:** an X.509 wildcard only covers **one** label. `*.cloud.traunseenet.com` covers `s3.cloud…` but **not** `api.s3.cloud…`. (Gateway API *listener* wildcards match one-or-more labels, so routing would work — but TLS would present the wrong cert. Hence a dedicated listener + cert.)
>
> DNS-01 via Cloudflare issues wildcards fine, including for LAN-only names like `*.local.traunseenet.com` — the zone is public even if the A records aren't.

### 4.4 The shared Gateway

New file `traefik/addons/gateway.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: traefik
  namespace: networking
spec:
  gatewayClassName: traefik
  listeners:
    - name: websecure-cloud
      port: 8443                     # MUST match the websecure entrypoint
      protocol: HTTPS                # CONTAINER port (8443), not the Service
      hostname: "*.cloud.traunseenet.com"   # port (443) — else the listener
      tls:                                  # is silently ignored
        mode: Terminate
        certificateRefs:
          - name: wildcard-cloud-traunseenet-tls
      allowedRoutes:
        namespaces:
          from: All
    - name: websecure-web
      port: 8443
      protocol: HTTPS
      hostname: "*.web.traunseenet.com"
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-web-traunseenet-tls
      allowedRoutes:
        namespaces:
          from: All
    - name: websecure-local
      port: 8443
      protocol: HTTPS
      hostname: "*.local.traunseenet.com"
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-local-traunseenet-tls
      allowedRoutes:
        namespaces:
          from: All
    - name: websecure-s3
      port: 8443
      protocol: HTTPS
      hostname: "api.s3.cloud.traunseenet.com"
      tls:
        mode: Terminate
        certificateRefs:
          - name: s3-api-cloud-traunseenet-tls
      allowedRoutes:
        namespaces:
          from: All
```

**Flux wiring:** the `addons` path is already stubbed (commented out) in `traefik/ks.yaml` — create a `traefik-addons` Kustomization with `path: .../traefik/addons`, `dependsOn: [traefik-base, cert-manager-addons]`, plus `addons/kustomization.yaml` listing `certificates.yaml` and `gateway.yaml`.

### Phase 1 verification gate

```bash
flux get ks gateway-api-crds traefik-base traefik-addons
kubectl get gatewayclass traefik            # ACCEPTED: True
kubectl get gateway -n networking traefik   # PROGRAMMED: True, ADDRESS = LB IP
kubectl get certificate -n networking       # all READY: True
kubectl get gateway -n networking traefik -o jsonpath='{.status.listeners}' | jq
# every listener: Accepted=True, ResolvedRefs=True, Programmed=True
```

All existing Ingresses must still work — nothing routed via Gateway API yet.

### Phase 1 execution log (2026-07-31, commit a3dc439)

Gate passed ~6 min after push. Notes vs. plan:

- v1.6.1 **standard** channel now carries more than expected: TCPRoute, TLSRoute, UDPRoute, BackendTLSPolicy, ListenerSets, plus a `safe-upgrades` ValidatingAdmissionPolicy that blocks accidental CRD downgrades.
- `statusAddress` was left at chart defaults — it auto-targets the chart's own Service (`networking/traefik`); Gateway `status.addresses` correctly shows `10.0.0.50`.
- GatewayClass `traefik` Accepted (`traefik.io/gateway-controller`); `supportedFeatures` includes TLSRoute (relevant for optional Phase 4).
- All 4 listeners Accepted/ResolvedRefs/Programmed=True; all 4 DNS-01 certs issued in ~3 min; zero 5xx on `websecure` throughout.

---

## 5. Phase 2 — Pilot app

### 5.1 Pick the pilot

**searxng** — stateless, low-stakes, single host, no special protocols. (Deliberately not gatus/uptimekuma, which are the monitoring; keep those on Ingress until the pattern is proven so they can alert on it.)

### 5.2 The HTTPRoute template

Every standalone Ingress in this repo converts with this template (this is why ingress2gateway isn't worth the tooling round-trip here — but see §5.4 if you prefer it):

```yaml
# kubernetes/apps/apps/searxng/searxng/app/httproute.yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: searxng
spec:
  parentRefs:
    - name: traefik
      namespace: networking
      sectionName: websecure-cloud
  hostnames:
    - searxng.cloud.traunseenet.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: searxng-web
          port: 8080          # ⚠ NUMERIC — look up the named port ("http")
                              #   in the Service; names are not allowed here
```

> **Phase 2 execution log (2026-07-31, commits b21797f + cutover):** pilot passed. HTTPRoute Accepted/ResolvedRefs, Ingress pruned, search verified HTTP 200 via the `@kubernetesgateway` service router. Findings for the bulk phases:
> - Traefik's service label is shadowed by the ServiceMonitor — query Prometheus with `exported_service=~".*@kubernetesgateway"`. Router-level metrics are off (`addRoutersLabels` not set). Old `@kubernetes` series go stale (not zero) when an Ingress is removed.
> - **Cert tie-break gotcha:** Harbor's chart Ingress references the manually-provisioned `traunseenet-cert` (SANs `*.traunseenet.com`, `*.cloud…`, `*.local…`, expires 2026-09-28). It lives in Traefik's global SNI store and currently beats the listener wildcards for `*.cloud`/`*.local` hosts that lack an exact cert. Harmless (valid cert), disappears when Harbor migrates in Batch D — but don't be surprised by "wrong" cert CNs until then.
> - Per-app verification is easiest from the local sandbox: `curl -sI https://<host>/` hits the LB directly.

Conversion rules from the current Ingress pattern:

| Ingress field/annotation | HTTPRoute equivalent |
|---|---|
| `ingressClassName: traefik` (or missing) | `parentRefs → networking/traefik` (explicit; no "default class" concept) |
| `router.entrypoints: websecure` | `sectionName: websecure-<tier>` |
| `cert-manager.io/cluster-issuer` + per-host `tls.secretName` | **dropped** — TLS lives on the Gateway listener (wildcard) |
| `rules[].host` | `hostnames[]` |
| `paths[]` (all are `pathType: Prefix`) | `rules[].matches[].path` `PathPrefix` |
| `backend.service.name/port.name` | `backendRefs[].name` + **numeric** `port` |

### 5.3 Pilot procedure

1. Add `httproute.yaml`, register it in `app/kustomization.yaml`. **Keep `ingress.yaml`.** Commit, reconcile.
2. Both now route (identical host/path → Traefik picks one deterministically; both target the same Service, so behavior is identical either way).
3. Verify:
   ```bash
   kubectl get httproute -n apps searxng -o jsonpath='{.status.parents}' | jq   # Accepted=True
   curl -sI https://searxng.cloud.traunseenet.com                                # 200
   openssl s_client -connect <LB-IP>:443 -servername searxng.cloud.traunseenet.com </dev/null 2>/dev/null \
     | openssl x509 -noout -subject   # CN=*.cloud.traunseenet.com
   ```
4. Delete `ingress.yaml` (+ kustomization entry). Commit, reconcile. Re-verify.
5. Confirm external-dns kept/re-created the record (source switched from `ingress` to `gateway-httproute`; same hostname, target now from Gateway status → same LB IP → effectively a no-op in Technitium; check external-dns logs and TTL).

**Rollback at any point:** `git revert` — the Ingress is re-applied and routes again within one reconcile; both providers stay enabled throughout the migration.

### 5.4 Optional: ingress2gateway assist

```bash
ingress2gateway print --providers=traefik \
  --input-file=kubernetes/apps/apps/<app>/<app>/app/ingress.yaml
```

v1.2.0's Traefik provider handles exactly the two annotations this repo uses. Caveats: it emits its own Gateway (discard it — use the shared one, fix `parentRefs`/`sectionName`) and keeps named ports (fix to numeric). Given that, hand-templating is usually faster.

---

## 6. Phase 3 — Bulk migration

One PR per batch. Suggested batches ordered by risk. **Backend ports marked "check" must be read from the app's Service manifest before writing the route.**

### Batch A — simple standalone apps

| App | File dir (`kubernetes/apps/…`) | Hostname(s) | Listener | Backend (numeric port: check Service) |
|---|---|---|---|---|
| searxng *(pilot, done)* | `apps/searxng` | searxng.cloud | websecure-cloud | `searxng-web` (`http`) |
| ntfy | `apps/ntfy` | ntfy.cloud | websecure-cloud | `ntfy` (`web`) |
| gatus | `apps/gatus` | gatus.cloud | websecure-cloud | `gatus` (`http-tcp`) |
| ~~uptimekuma~~ | `apps/uptimekuma` | uptime.cloud | — | **SKIP: dead app** (`suspend: true`, no Deployment/pod/Ingress since Apr 2026). Edit committed but inert. |
| karakeep | `apps/karakeep` | karakeep.cloud | websecure-cloud | `karakeep` (`http`) |
| bifrost | `apps/bifrost` | bifrost.cloud | websecure-cloud | `bifrost` (`http`) |
| open-webui | `apps/open-webui` | gpt.cloud | websecure-cloud | `open-webui` (8080) |
| pocketid | `auth/pocketid` | pocketid.cloud | websecure-cloud | `pocket-id` (1411) |
| longhorn | `storage/longhorn-system` | longhorn.local | **websecure-local** | `longhorn-frontend` (80) |

*open-webui note: verify SSE/streaming chat still works after cutover (long-lived responses; entrypoint readTimeout 360s applies as before).*

> **Batch C execution log (2026-07-31, done):** immich, paperless, gitea migrated; zero 5xx; app-level health verified (immich `/api/server/ping`, gitea `/api/v1/version`). Notes: immich's Ingress was the trailing document inside `server.yaml` (multi-doc) — removed just that doc. immich's kustomize `namespace: apps-immich` is overridden by the Flux Kustomization `targetNamespace: apps`, so its HTTPRoute lands in `apps`. gitea SSH (:22) is not an Ingress and is unaffected.

### Batch B — multi-path / multi-host / dual-tier

> **Execution log (2026-07-31, done):** fin, jellyfin, navidrome, minio migrated; zero 5xx. **Decision: both `.web` endpoints were dropped** — jellyfin and navidrome are now `.cloud`-only (jellyfin.web/navidrome.web return 404). The `websecure-web` listener is consequently unused but stays provisioned for future apps. Verified: fin's `/api`↔`/` split routes to uvicorn↔nginx correctly (`/api/health` = 200); `api.s3.cloud` presents its **dedicated** cert via the `websecure-s3` listener (the wildcard-gap design working as intended). **Follow-up:** newt/Pangolin tunnel may still advertise the two dropped `.web` hosts — prune from tunnel config separately.

**fin** (`apps/fin`) — two path rules; Gateway API gives longer-prefix precedence automatically:

```yaml
  hostnames: [fin.cloud.traunseenet.com]
  rules:
    - matches: [{path: {type: PathPrefix, value: /api}}]
      backendRefs: [{name: fin-api, port: <check>}]
    - matches: [{path: {type: PathPrefix, value: /}}]
      backendRefs: [{name: fin-web, port: <check>}]
```

**jellyfin** (`apps/jellyfin`) — one Ingress, two hosts in *different tiers* → one HTTPRoute, **two parentRefs**:

```yaml
  parentRefs:
    - {name: traefik, namespace: networking, sectionName: websecure-cloud}
    - {name: traefik, namespace: networking, sectionName: websecure-web}
  hostnames:
    - jellyfin.cloud.traunseenet.com
    - jellyfin.web.traunseenet.com
```
*Hostname/listener intersection sorts it out: each hostname binds to its matching listener. Verify WebSocket (SyncPlay, dashboard sessions) post-cutover — works out of the box with Traefik's Gateway provider, but confirm.*

**navidrome** (`apps/navidrome`) — replace both `ingress.yaml` and `ingress-external.yaml` with one HTTPRoute (same two-parentRef pattern as jellyfin, both hosts → `navidrome:<port of "web">`). This also fixes the current reliance on a default IngressClass (neither Ingress sets `ingressClassName` today).

**minio** (`storage/minio`) — two HTTPRoutes:
- `s3.cloud.traunseenet.com` → `minio-service:9001` (console), listener `websecure-cloud`
- `api.s3.cloud.traunseenet.com` → `minio-service:9000` (S3 API), listener **`websecure-s3`**
*Post-cutover: test an actual S3 client (large multipart PUT) — the API host is the one external tools depend on.*

### Batch C — heavier apps (test carefully)

| App | Hostname | Listener | Post-cutover test |
|---|---|---|---|
| immich (`apps/immich`, route embedded in `server.yaml` today) | immich.cloud | websecure-cloud | **Bulk upload from mobile app.** HTTPRoute timeouts are ignored by Traefik (#11902); the existing entrypoint `readTimeout: 360s` continues to govern uploads — same as today, so behavior should be unchanged. If long uploads ever 502, raise it at the entrypoint level |
| paperless (`apps/paperless-ngx`, note nested `app/app/` dir) | paperless.cloud | websecure-cloud | Large document upload + WebSocket status updates |
| gitea (`storage/gitea`) | gitea.cloud | websecure-cloud | `git clone`/`push` over HTTPS, large repo. (SSH is ClusterIP-only today — unaffected) |

### Batch D — Helm-values-embedded ingresses

> **Execution log (2026-07-31, done):** all five migrated, zero 5xx. Prefer each chart's **native Gateway API support** where it's stable; standalone HTTPRoute only where it isn't:
> - **grafana** → operator `spec.httpRoute` (stable, native).
> - **harbor** (harbor-helm 1.19.1) → native `expose.type: route` + `expose.tls.enabled: false`. Renders the exact path-split (`/api`,`/service`,`/v2`,`/c`→harbor-core; `/`→harbor-portal), **no nginx, no topology change**. Verified `/v2/`→401 (correct docker challenge), all 7 components healthy.
> - **jaeger** → the release was misconfigured (v1 keys on the v2 chart 4.12.0, so no ingress ever rendered). Rewrote to proper **v2** values (`jaeger.enabled` + native stable `jaeger.httproute`; memory storage is the v2 default; service stays `jaegertracing:16686`). The native route **restored** external access that was silently broken.
> - **prometheus + alertmanager** (kube-prometheus-stack 82.18.0) → chart `ingress.enabled: false` + **standalone HTTPRoutes**. The chart *does* have a native `route:` block but it's explicitly **BETA/unsupported**, so avoided.
> - **Cert cleanup deferred to Phase 5:** `traunseenet-cert` (manually pre-provisioned, not owned by Harbor's ingress) persists as an orphaned secret and Traefik keeps serving it for `*.cloud` hosts. Cosmetic (valid cert). Delete the secret in Phase 5 → cert-manager wildcard takes over.
> - **Newly found, still on Ingress:** `media-stack-ingress` (`secured` ns) — bazarr/radarr/sonarr/lidarr/jackett/prowlarr/transmission via `media-stack-tunnel`. Not in any batch above; must migrate before Phase 5 can disable `kubernetesIngress`.

These aren't standalone files; each needs its chart-specific approach. General pattern: **disable the chart's ingress, add a standalone `httproute.yaml`** next to the HelmRelease.

| App | Where | Approach |
|---|---|---|
| **grafana** | `observability/grafana/instances/grafana-instance.yaml` | The Grafana Operator supports Gateway API natively and the CR **already has a commented-out `httpRoute` block** — remove `spec.ingress`, uncomment/adapt `spec.httpRoute` (host `grafana.cloud`, parentRef `networking/traefik`, `sectionName: websecure-cloud`) |
| **prometheus + alertmanager** | `observability/prometheus/app/release-prometheus.yaml` | Recent kube-prometheus-stack versions expose Gateway API `route` values (`prometheus.route`, `alertmanager.route`); check the deployed chart version. If present, use them; otherwise set `ingress.enabled: false` and add two standalone HTTPRoutes (`prometheus.cloud` → prometheus Service :9090, `alertmanager.cloud` → alertmanager Service :9093) |
| **jaeger** | `observability/jaeger/app/release.yaml` | Set the allInOne ingress `enabled: false`, standalone HTTPRoute `jaeger.cloud` → jaeger query Service (:16686) |
| **harbor** | `storage/harbor/harbor/app/release.yaml` | Switch `expose.type` to `clusterIP`, keep `externalURL: https://harbor.cloud.traunseenet.com`, add one HTTPRoute mirroring the chart's path split: `/api/`, `/service/`, `/v2/`, `/c/` → `harbor-core` (:80), `/` → `harbor-portal` (:80). **Bonus:** the wildcard listener cert replaces the mystery pre-provisioned `traunseenet-cert` secret. Test `docker login` + push/pull afterwards (`/v2/` path is the critical one) |
| **traefik dashboard** | `traefik/base/release.yaml` `extraObjects` | Replace the embedded Ingress with an embedded HTTPRoute (`traefik.cloud` → `traefik-api:8080`, parentRef `networking/traefik`, `sectionName: websecure-cloud` — same-namespace parentRef, no issue) |

---

## 7. Phase 4 — Special case: OpenShell (TLS passthrough)

**Recommendation: keep `IngressRouteTCP` for now.** It works, the `kubernetesCRD` provider stays enabled anyway, and passthrough via Gateway API has less mileage in Traefik. This is explicitly *not* a migration blocker — HTTP migration completes independently.

**Optional later** (TLSRoute is standard-channel and Traefik supports it):

```yaml
# Extra Gateway listener (same port 8443; SNI disambiguates):
    - name: tls-openshell
      port: 8443
      protocol: TLS
      hostname: openshell.cloud.traunseenet.com
      tls:
        mode: Passthrough
      allowedRoutes:
        namespaces:
          from: All
---
apiVersion: gateway.networking.k8s.io/v1
kind: TLSRoute
metadata:
  name: openshell
  namespace: apps
spec:
  parentRefs:
    - {name: traefik, namespace: networking, sectionName: tls-openshell}
  hostnames: [openshell.cloud.traunseenet.com]
  rules:
    - backendRefs: [{name: openshell, port: 8080}]
```

If/when doing this: also uncomment `--source=gateway-tlsroute` in external-dns, and verify the openshell CLI's mTLS handshake end-to-end before deleting the IngressRouteTCP. Note the wildcard `websecure-cloud` listener and this passthrough listener overlap on SNI — the exact-hostname listener must win; **test this specifically**, and if Traefik misbehaves, fall back to IngressRouteTCP.

---

## 8. Phase 5 — Cleanup

Only after **every** Ingress is gone (`kubectl get ingress -A` returns nothing except, possibly, cert-manager transients):

1. **Disable the Ingress provider** in the Traefik HelmRelease:
   ```yaml
   providers:
     kubernetesIngress:
       enabled: false     # or delete the whole block
   ```
   Keep `kubernetesCRD` (openshell IngressRouteTCP + future middlewares).
2. **Delete orphaned cert secrets.** cert-manager garbage-collects the per-Ingress `Certificate` objects when their owning Ingresses are deleted, but the **`*-cert` Secrets remain**:
   ```bash
   kubectl get certificate -A          # should list only the 4 networking wildcards
   kubectl get secret -A | grep -- '-cert'   # review, then delete leftovers
   ```
3. Remove `ingressClass: traefik` from the `kubernetesCRD` provider block (only served the Ingress path).
4. Housekeeping while in the file (optional, unrelated): `--log.level=DEBUG` and `--api.insecure=true` are still set from earlier debugging.
5. Update the repo's own docs/readme to document the HTTPRoute pattern for new apps.

---

## 9. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Listener port mismatch (using 443 instead of 8443) | High (classic trap) | Listener ignored, routes 404 | Ports are correct in §4.4; check `status.listeners` at the Phase 1 gate |
| Named backend ports copied into HTTPRoutes | High if careless | Route rejected (`ResolvedRefs: False`) | Numeric-port lookup is a required step per app; status check in per-app verification |
| CRDs pruned by Flux | Low | **Catastrophic** — all Gateways/Routes deleted | `prune: false` on `gateway-api-crds`; never remove that Kustomization |
| Traefik cert-selection bugs (#11972/#12742) | Low on v3.7.9 | Wrong cert served | Chart ≥ 41.1.0 (Phase 0) + one certRef per listener by design |
| `api.s3` not covered by wildcard | Certain if missed | S3 API cert error | Dedicated listener + cert (§4.3/§4.4) |
| Per-route timeouts unavailable (#11902) | Certain | None *today* (config parity with current entrypoint 360s) | Keep timeout config at entrypoint level; don't write `spec.timeouts` expecting it to work |
| Hostname claimed by both an Ingress and an HTTPRoute mid-migration | By design | None — both target the same Service | Keep overlap windows short anyway; delete the Ingress after verifying |
| external-dns record flap during source handover | Low | Brief resolution failure (60s TTL) | `statusAddress` config makes the target IP identical; watch external-dns logs on pilot |
| Harbor path-split HTTPRoute wrong | Medium | docker push/pull broken | Mirror chart ingress paths exactly; test `docker login`/push before deleting old config |
| newt/Pangolin tunnel + `.web` hosts | Low | External access broken | Tunnel targets Traefik, which still terminates `.web` TLS (now via wildcard) — verify jellyfin.web + navidrome.web from outside the LAN after Batch B |

---

## 10. Per-app verification checklist

For every migrated app:

- [ ] `kubectl get httproute -n <ns> <name>` → all parents `Accepted: True`, `ResolvedRefs: True`
- [ ] `curl -sI https://<host>` → expected status, correct wildcard cert (`openssl s_client -servername`)
- [ ] DNS record still resolves to the LB IP (Technitium / `dig @10.0.0.99`)
- [ ] App-specific function test (uploads, WebSocket, S3 client, docker push, SSE — per §6 notes)
- [ ] Old Ingress deleted from git; `flux get ks <app>` Ready
- [ ] Traefik logs clean for the host (`kubectl logs -n networking ds/traefik | grep <host>`)

---

## 11. Execution order at a glance

| Phase | Content | Gate |
|---|---|---|
| 0 | Traefik chart 39.0.8 → 41.1.0; verify CRD state + external-dns RBAC | All Ingresses work on v3.7.9 |
| 1 | CRDs (Flux) → provider on → wildcard Certs → shared Gateway | Gateway `Programmed`, listeners green, certs Ready, Ingresses untouched |
| 2 | Pilot: searxng | Full checklist passes incl. Ingress deletion + rollback confidence |
| 3A–D | Bulk: simple → multi-host → heavy → Helm-embedded | Checklist per app; batch = 1 PR |
| 4 | (Optional, anytime later) openshell → TLSRoute | mTLS handshake verified |
| 5 | Disable `kubernetesIngress`, delete orphaned cert secrets | `kubectl get ingress -A` empty; all apps green |

**Estimated effort:** Phases 0–2 are the careful part (chart upgrade + foundation + pilot). Phases 3A–C are mechanical (~10 min/app including verification). Phase 3D needs per-chart attention, Harbor being the fiddliest.

---

## 12. Sources

- Traefik Gateway provider: <https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-gateway/> · routing: <https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/gateway-api/>
- Traefik helm chart values / releases: <https://github.com/traefik/traefik-helm-chart>
- Gateway API v1.6.1: <https://github.com/kubernetes-sigs/gateway-api/releases/tag/v1.6.1> · implementations/conformance: <https://gateway-api.sigs.k8s.io/implementations/>
- Traefik issues: [#11902 timeouts](https://github.com/traefik/traefik/issues/11902) · [#11972 multi-certRefs](https://github.com/traefik/traefik/issues/11972) · [#12742 hostname/cert](https://github.com/traefik/traefik/issues/12742) · [#13247 port-443 TLS](https://github.com/traefik/traefik/issues/13247)
- cert-manager Gateway usage: <https://cert-manager.io/docs/usage/gateway/>
- external-dns Gateway sources: <https://github.com/kubernetes-sigs/external-dns/blob/master/docs/sources/gateway.md>
- ingress2gateway: <https://github.com/kubernetes-sigs/ingress2gateway> (Traefik provider since v1.1.0)
- Official migration guide: <https://gateway-api.sigs.k8s.io/guides/getting-started/migrating-from-ingress/>
