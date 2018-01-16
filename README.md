# Transition
### [Step-by-step guide](how-to-transition.md) to transitioning from `cf-release` to `cf-deployment`

This repo contains tools for migrating
from [cf-release](https://github.com/cloudfoundry/cf-release)
to [cf-deployment](https://github.com/cloudfoundry/cf-deployment).
The included tools are:
- `extract-vars-store-from-manifests.sh`: Extracts credentials from your existing deployment manifests
  to build a vars-store for cf-deployment.
- `cfr-to-cfd.yml`: An ops-file that enables the migration from cf-release to cf-deployment.
- `remove-cf-networking-for-transition.yml`: Opts out of cf-networking
  so that deployers can migrate without also adding the new networking stack.
- `remove-routing-components-for-transition.yml`: Opts out of the Routing applied
  so that deployers can migration without also adding the Routing API and TCP Router
  or their dependencies.
- `keep-etcd-for-transition.yml`: Adds a single instance
of `etcd`
to cf-deployment
for the purpose of transition.
This opsfile pins loggregator to version 99.x and
also holds `etcd` at a static IP address.
Deployers must provide the IP address.
- `enable-doppler-announce.yml`: Configures `doppler`
to announce presence via etcd.
Requires `keep-etcd-for-transition.yml`.
- `rename-etcd-network.yml`: Allows renaming
of the `etcd`
instance's network
added by using `keep-etcd-for-transition.yml`.
Deployers must provide the name.
- `keep-syslog-drain-binder-for-transition.yml`: Retains the `syslog_drain_binder` job
on the `doppler` instance_group
and properties.
Requires `keep-etcd-for-transition.yml`.
- `opt-out-of-cf-syslog-drain-release-for-transition.yml`: Removes `cf-syslog-drain` components
from cf-deployment.  Intended to be used in conjunction with `keep-syslog-drain-binder-for-transition.yml`
to continue using syslog drain
while minimizing the number of duplicate messages logged
during the transition deployments.
- `migrate-postgres.yml`: Migrates the
`postgres_z1` instance_group
of cf-release
to the `database` instance_group
of cf-deployment.
- `migrate-webdav.yml`: Migrates the webdav
`blobstore_z1` instance_group
of cf-release
to the `singleton-blobstore` instance_group
of cf-deployment.

## Tools

### `extract-vars-store-from-manifests.sh`: Credential extraction

#### Usage
```
usage: extract-vars-store-from-manifests.sh [required arguments]
  required arguments:
    -ca, --ca-keys         Path to your created CA Keys file
    -cf, --cf-manifest     Path to your existing Cloud Foundry Manifest
    -d,  --diego-manifest  Path to your existing Diego Manifest
  optional arguments:
    -N,  --cf-networking   Flag to extract cf-networking creds from the Diego Manifest
    -r,  --routing         Flag to extract routing deployment creds from the Cloud Foundry Manifest
```
The output of `extract-vars-store-from-manifests.sh`
in a vars-store file you can use
with the `--vars-store` option
when deploying with `cf-deployment`
and the new `bosh` CLI.

#### Dependencies: Spiff (Yes, Spiff)
`extract-vars-store-from-manifests.sh` uses [spiff](https://github.com/cloudfoundry-incubator/spiff)
under the hood to build the vars-store.
To install `spiff`,
download the latest binary [here][spiff-releases],
extract it from its tarball,
and put it on your path.

If you already have `spiff` installed,
please check that you have at least version 1.0.8.
You can use `spiff --version` to check
if an upgrade is necessary.

#### <a id="ca-keys"></a> Dependencies: CA Private Key Stub File
`cf-deployment`-based deployments use
the v2 `bosh` CLI or [Credhub](https://github.com/cloudfoundry-incubator/credhub)
to manage deployment credentials,
including CA private keys.
If cf-deployment adds new certificates,
they'll need to be signed by a CA,
and so credential management tools like Credhub
will need access to the CA private key.

Because CA private keys aren't included in the CF or Diego manifests,
we'll need your help to fill out those values in the vars-store or Credhub.
Users must provide a Private Key Stub using the `-ca` flag.
We've included an example stub below:

```
---
from_user:
  diego_ca:
    private_key: |
      multi
      line
      example
      key
  etcd_ca:
    private_key: |
  etcd_peer_ca:
    private_key: |
  consul_agent_ca:
    private_key: |
  loggregator_ca:
    private_key: |
  uaa_ca:
    private_key: |
```

### `cfr-to-cfd.yml`: Transition ops-file
This is an ops file
to be used when deploying using `cf-deployment`
for the first time
while targeting an existing `cf-release`-based deployment.

It should be applied after
all other appropriate ops-files
and in conjunction with the ops-file
to scale down etcd for cluster changes.

## <a id="prerequisites"></a> Migration Prerequisites
To migrate to cf-deployment
with the tools and process we've designed and tested
so far,
you'll need to fulfill a number of requirements:
- You have [`v2.0.42`](https://github.com/cloudfoundry/bosh-cli/releases/tag/v2.0.42)
or higher of the `bosh` cli
- You have existing deployments of
  `cf-release`
  and
  `diego-release` on AWS.
- You've got TLS enabled and configured correctly
  (this is discussed in some length in the next section)
- Your databases are external to your cf-release deployment
  or you are using the integrated `postgres` job.
- Your blobstore is external to your cf-release deployment
  or you are using the integrated `blobstore` job.
- You will likely need
  to create a new database
  for the Routing API,
  which is included by default in CF Deployment.
  Alternatively, you can opt-out of the new Routing components
  with the `remove-routing-components-for-transition.yml`
  ops file from this repository. See the database section below for details.
- You will likely need
  to create a new database
  for the cf-networking,
  which is included by default in CF Deployment.
  Alternatively, you can opt-out of the cf-networking components
  with the `remove-cf-networking-for-transition.yml`
  ops file from this repository. See the database section below for details.

The following sections discuss these prerequisites
and their relationships to our tools
in more depth.

Our tests and tooling
assume you are migrating an AWS environment.
**If you have a different IaaS in production
and you'd like to migrate it,
we'd love to hear from you!
Please open an issue describing your situation.**

### Required TLS Certificate Topology
`cf-deployment` enables TLS validation
in most places,
which may be a more strict configuration
than cf-release provided in its manifest generation scripts.

You'll need to configure jobs
to trust the certificate authorities
used to sign one another's certs.
Getting these relationships right is complicated,
and there is more than one possible working arrangement.
`cf-deployment` expects a particular arrangement,
documented below.

If you have a different certificate topology,
you'll need to either migrate to ours,
or manage the transition on your own.

Below is a list of Certificate Authorities
with indented lists of certificates
that must share an authority.
More-shared/permissive topologies will also work
as long as all members of the sub-lists share CAs.

- etcd-ca
  - etcd_server
  - etcd_client
- etcd_peer_ca
  - etcd_peer
- consul_agent_ca
  - consul_server
  - consul_agent
- service_cf_internal_ca
  - blobstore_tls
  - diego_auctioneer_client
  - diego_auctioneer_server
  - diego_bbs_server
  - diego_rep_client
  - diego_rep_agent
  - cc_tls
  - cc_bridge_tps
  - cc_bridge_cc_uploader
  - cc_bridge_cc_uploader_server
- loggregator_ca
  - loggregator_tls_statsdinjector
  - loggregator_tls_metron
  - loggregator_tls_syslogdrainbinder
- router_ca
  - router_ssl
- uaa_ca
  - uaa_ssl
  - uaa_login_saml

### Required Database Configuration
The tools in this repo assume
that production deployers are using an external database service,
such as RDS,
or a BOSH-deployed Postgres.

Deployers using an external database service
must use the `use-external-dbs.yml` ops file.
This ops file requires a number of variables
be provided in vars-files,
as [documented][cf-d-ops-files-list] in the `cf-deployment` readme.

Deployers using a BOSH-deployed Postgres
must use the `use-postgres.yml` ops file
to build the target `cf-deployment` manifest.
During the transition deploy
they must also use the `cf-deployment-transition/migrate-postgres.yml` ops-file
to ensure their data is transferred to the new instance.

#### New databases
If you haven't already deployed the Routing API,
and decide to add it as part of the transition to cf-deployment,
you'll need to set up a new external database for it.
The information for accessing the database,
like the address or password,
will need to be provided to `use-external-dbs.yml`.

Similarly,
you may decide to deploy the CF Networking stack
as part of your transition.
In that case, you'll need another external database for the CF Networking jobs.

## Tests and Contributions
We're happy to accept feedback
in the form of issues and pull-requests.
If you make a change,
please run our tests
with `transition/test-suite.sh`,
and update the fixtures appropriately.

[spiff-releases]: https://github.com/cloudfoundry-incubator/spiff/releases
[cf-d-ops-files-list]: https://github.com/cloudfoundry/cf-deployment/blob/master/README.md#ops-files
