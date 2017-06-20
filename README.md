# Transition

**The tools in this repo
have not been tested
in any production transitions
and is still under active development.
We'll update this section when the transition
has been sufficiently tested.**

This repo contains tools for migrating
from [cf-release](https://github.com/cloudfoundry/cf-release)
to [cf-deployment](https://github.com/cloudfoundry/cf-deployment).
The included tools are:
- `transition.sh`: Extracts credentials from your existing deployment manifests
  to build a vars-store for cf-deployment.
- `cfr-to-cfd.yml`: An ops-file that enables the migration from cf-release to cf-deployment.
- `remove-cf-networking.yml`: Opts out of cf-networking
  so that deployers can migrate without also adding the new networking stack.
- `remove-routing-api-for-transition.yml`: Opts out of the Routing applied
  so that deployers can migration without also adding the Routing API
  and its dependencies.

## Tools

### `transition.sh`: Credential extraction

#### Usage
```
usage: transition.sh [required arguments]
  required arguments:
    -ca, --ca-keys         Path to your created CA Keys file
    -cf, --cf-manifest     Path to your existing Cloud Foundry Manifest
    -d,  --diego-manifest  Path to your existing Diego Manifest
  optional arguments:
    -N,  --cf-networking   Flag to extract cf-networking creds from the Diego Manifest
    -r,  --routing         Flag to extract routing deployment creds from the Cloud Foundry Manifest
```
The output of `transition.sh`
in a vars-store file you can use
with the `--vars-store` option
when deploying with `cf-deployment`
and the new `bosh` CLI.

#### Dependencies: Spiff (Yes, Spiff)
`transition.sh` uses [spiff](https://github.com/cloudfoundry-incubator/spiff)
under the hood to build the vars-store.
To install `spiff`,
download the latest binary [here][spiff-releases],
extract it from its tarball,
and put it on your path.

#### Dependencies: CA Private Key Stub File
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

This section will be updated with better instructions
as our support for the transition process improves.

## Migration Prerequisites
To migrate to cf-deployment
with the tools and process we've designed and tested
so far,
you'll need to fulfill a number of requirements:
- you have existing deployments of
  `cf-release`
  and
  `diego-release` on AWS.
- you've got TLS enabled and configured correctly
  (this is discussed in some length in the next section)
- your databases and blobstores are external to your cf-release deployment
  (for example, your database could be in a separate database deployment, or a service like RDS).
- you will likely need
  to create a new database
  for the routing_api,
  which is included by default in CF Deployment.
  Alternatively, you can opt-out of the routing_api
  with the remove-routing-api-for-transition.yml
  ops file from this repository. See the database section below for details.

The following sections discuss these prerequisites
and their relationships to our tools
in more depth.

Our tests and tooling
assume you are migrating an AWS environment.
If you have a different IaaS in production
and you'd like to migrate it,
we'd love to hear from you!
Please open an issue describing your situation.

### Required TLS Certificate Topology
It is important to note that TLS validation
is enabled throughout `cf-deployment`.
This configuration may be more strict
about TLS configuration
than configurations based on `cf-release` were.

We assume you are using self-signed certificates
for internal TLS communication.
This requires configuring jobs
to trust the certificate authorities
used to sign one another's certs.
Getting these relationships right is complicated,
and there is more than one possible working arrangement.
`cf-deployment` expects a particular arrangement,
documented below.
If you have a different certificate topology,
you'll need to either migrate to ours,
or manage the transition on your own.

This is a list of Certificate Authorities
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

### Required Database and Blobstore Configuration
Our tools assume
an external S3 blobstore
and an external AWS RDS database.

The transition deployment assumes
and requires
the use of the `use-external-dbs.yml`
and `use-s3-blobstore.yml` ops files.
Those ops files require a number of variables
be provided in vars-files,
as [documented][cf-d-ops-files-list] in the `cf-deployment` readme.

You will need to manually extract and specify
the configuration details
for your external persistence providers.

The routing_api database
should be external to your deployment.
For example, you may want
to use an Amazon RDS instance for this purpose.
To configure the routing_api,
you will need to provide in your vars-file:
  - db_type
  - db_port
  - routing_api_db_name
  - routing_api_db_address
  - routing_api_db_password
  - routing_api_db_username

## Tests and Contributions
We're happy to accept feedback
in the form of issues and pull-requests.
If you make a change,
please run our tests
with `transition/test-suite.sh`,
and update the fixtures appropriately.

[spiff-releases]: https://github.com/cloudfoundry-incubator/spiff/releases
[cf-d-ops-files-list]: https://github.com/cloudfoundry/cf-deployment/blob/master/README.md#ops-files
