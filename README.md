# Transition
The tools in this repo
have not been tested
in any production transitions.

Do not use them
except if you wish to discover
the ways in which they may fail.

## Usage

### Variable Extraction Script
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
This is intended to result
in a vars-store file you can use
with the `--vars-store` option
when deploying with `cf-deployment`
and the new `bosh` CLI.

When you deploy with this vars-store,
you will also need to use
the `cfr-to-cfd.yml` ops-file.
See the **Transition Deployment**
section for more details.

#### Yes, Spiff
These tools use spiff templates
to extract values from a deployment manifest
based on `cf-release`,
and store them in a vars-store
for use with `cf-deployment`
and the new `bosh` cli.

To install `spiff`,
download the latest binary [here][spiff-releases],
extract it from its tarball,
and put it on your path.

#### Why Create a CA Private Key Stubs File
While we can automatically obtain 
your CA certificates
from your existing CF manifest,
we're unable to do the same for 
their private keys.

`CF Release` relied on
the Bosh 1.x CLI,
which did not have a role
in managing your deployments' certificates.
The Bosh 2.x CLI 
that `CF Deployment` relies on now, does.

In order to transition your CF deployment 
to the new world,
we'll need your help.
Providing the CA keys to us now allows 
Bosh to use the correct CA cert and key to 
sign new certificates as they become necessary
in the future.

The CA private key stub file is required.

#### Example CA Private Keys Stubs File
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

### Transition Deployment
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

### Prerequisites
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

#### Required TLS Certificate Topology
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

#### Required Database and Blobstore Configuration
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

### Tests and Contributions
We're happy to accept feedback
in the form of issues and pull-requests.
If you make a change,
please run our tests
with `transition/test-suite.sh`,
and update the fixtures appropriately.

[spiff-releases]: https://github.com/cloudfoundry-incubator/spiff/releases
[cf-d-ops-files-list]: https://github.com/cloudfoundry/cf-deployment/blob/master/README.md#ops-files
