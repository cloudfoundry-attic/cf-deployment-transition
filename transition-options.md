# Transition Options

Depending on your
current deployment of Cloud Foundry,
there may be component differences
between cf-release and cf-deployment.

There are some decisions to can make
regarding when and how to introduce
the new CF components that cf-deployment
comprises.

- [Are you using HAProxy?](#haproxy)
- [Decide How to Handle your Blobstore](#blobstore)
- [Decide How to Handle your Database](#database)
- [Decide How to Handle the Routing Release](#routing-release)
- [Decide How to Handle the CF Networking Release](#cf-networking-release)
- [Decide How to Handle the Application Syslog Drain Infrastructure](#syslog-drain)

## <a id="haproxy"></a> Are you using HAProxy?

`cf-release` ships with an optional `haproxy`
that can be used as a singleton load-balancer
for the entire deployment.
This is common in
vSphere or OpenStack deployments
as they do not offer load-balancers
built-in.
If you have chosen this path
and wish to migrate your `haproxy`
to `cf-deployment`,
apply the `migrate-haproxy.yml` opsfile
in the same deployments
as you apply the `cfr-to-cfd.yml` opsfile.

Before you transition you must modify
the cloud-config
on your BOSH director
to _exclude_ the IP address
of the `router`
and `ha_proxy_z1` nodes
from the `static_ip` range
of your network config.

You must also apply the `cf-deployment/operations/use-haproxy.yml`
opsfile to configure `cf-deployment`
to use `haproxy` in all deployments
of cf-deployment.

If you want to keep
the same SSL certificate
that you used in `cf-release`
for your `haproxy`,
you must also apply the `cf-deployment/operations/legacy/keep-haproxy-ssl-pem.yml`.

**NOTE** you must use the legacy opsfile AND the `use-haproxy.yml`
opsfile in perpetuity - not just for the transition.

## <a id="database"></a> Decide How to Handle your Database

`cf-release` ships with a `postgres` database
by default.
Many production deployers
have chosen to use external databases
such as `rds`.
This transition tooling supports both.
In order to migrate
your internal `postgres` database,
apply the `migrate-postgres.yml` opsfile
in the same deployments
as you apply the `cfr-to-cfd.yml` opsfile.

Before you transition you must modify
the cloud-config
on your BOSH director
to _exclude_ the IP address
of the `postgres_z1` node
from the `static_ip` range
of your network config.

You must also apply the `cf-deployment/operations/use-postgres.yml`
opsfile to configure `cf-deployment`
to use `postgres` in all deployments
of `cf-deployment`.

Since the database usernames and
database names are different
between `cf-release` and `cf-deployment`,
you must also apply the `cf-deployment/operations/legacy/keep-original-postgres-configuration.yml`.

**NOTE** you must use the legacy opsfile AND the `use-postgres.yml`
opsfile in perpetuity - not just for the transition.
Make sure **NOT** to use the `use-external-dbs.yml` opsfile
from `cf-deployment`.


## <a id="blobstore"></a> Decide How to Handle your Blobstore

`cf-release` ships with a `webdav` blobstore
by default, as does `cf-deployment`.
Many production deployers
have chosen to use external blobstores
such as `s3`.
This transition tooling supports both.
In order to migrate
your internal `webdav` blobstore,
apply the `migrate-webdav.yml` opsfile
in the same deployments
as you apply the `cfr-to-cfd.yml` opsfile.
If you have customized
the name of the directory keys
for your blobstore, please also use the
`cf-deployment/operations/legacy/keep-original-blobstore-directory-keys.yml` opsfile
to maintain those keys.

**NOTE** you must use the legacy opsfile in perpetuity -
not just for the transition.
Make sure **NOT** to use the `use-s3-blobstore.yml` opsfile
from `cf-deployment`.

## <a id="routing-release"></a> Decide How to Handle the Routing Release

If you have not yet deployed `routing-release`
in your existing cf-release based deployment,
you must decide
whether you want to introduce the
routing components
as part of your transition.
One of the routing components
-- the Routing API --
requires an additional database,
so some operator work will be required to deploy it.
Operators may either set up the necessary database,
or use `remove-routing-components-for-transition.yml`
to postpone this step.
You will need to apply
this ops file until
you are ready to include
the routing components.

## <a id="cf-networking-release"></a> Decide How to Handle the CF Networking Release

If you have not yet deployed `cf-networking-release`
in your existing cf-release based deployment,
you must decide
whether you want to introduce the
networking components
as part of your transition.
Some networking components
-- the `policy-server` and `silk-controller` --
require an additional databases,
so some operator work will be required to deploy them.
Operators may either set up the necessary databases,
or use `remove-cf-networking-for-transition.yml`
to postpone this step.
You will need to apply
this ops file until
you are ready to include
the networking components.

## <a id="syslog-drain"></a> Decide How to Handle the Application Syslog Drain Infrastructure

cf-release based CF deployments
use `syslog_drain_binder`
for its application-level
syslog drain infrastructure.

cf-deployment introduces
`cf-syslog-drain-release`,
a separate Bosh release
for application-level 
syslog drain infrastructure.

Depending on your needs,
you may want to control
whether or not to opt-in
to the new infrastructure
during your transition
from cf-release to cf-deployment.

There are three options:

---
### Option 1: Switch to `cf-syslog-drain-release` During Transition

Choose this option if
your users can tolerate
syslog drain downtime
during the transition deployment.
In this case,
there are no
special opsfiles
to apply.

---
### Option 2: Keep `syslog_drain_binder` and Deploy `cf-syslog-drain-release` During Transition

Choose this option if
your users can not tolerate
syslog drain downtime
during the transition deployment,
AND are willing
to pay for
a larger number
of duplicate logs.
The window of time
for duplicate logs
will start with
the transition deployment,
and last until
a subsequent deployment
which removes `syslog_drain_binder`.

1. In the transition deployment, include:
    - `keep-etcd-for-transition.yml`
    - `enable-doppler-announce.yml`
    - `keep-syslog-drain-binder-for-transition.yml`
    - optional: `rename-etcd-network.yml`
      (only if you've elected to use `cf-deployment/operations/rename-network.yml`)

1. In the next deployment,
omit both `enable-doppler-announce.yml` and
`keep-syslog-drain-binder-for-transition.yml` while keeping:
    - `keep-etcd-for-transition.yml`
    - optional: `rename-etcd-network.yml`
      (only if you've elected to use `cf-deployment/operations/rename-network.yml`)

1. In subsequent deployments,
omit the remaining transition operations.

---
### Option 3: Keep `syslog_drain_binder` and Deploy `cf-syslog-drain-release` Later

Choose this option if
your users can not tolerate
syslog drain downtime
during the transition deployment,
and you want to MINIMIZE
the window of time
users will have to pay
for duplicate logs.

You'll accomplish this
in three steps.
During the transition, nothing changes.
In the next deployment,
you'll be running both
`syslog_drain_binder` and `cf-syslog-drain-release`.
In the final, and subsequent deployments,
you'll remove `syslog_drain_binder`.

1. In the initial transition deployment, include:
    - `keep-etcd-for-transition.yml`
    - `enable-doppler-announce.yml`
    - `keep-syslog-drain-binder-for-transition.yml`
    - `opt-out-of-cf-syslog-drain-release-for-transition.yml`
    - optional: `rename-etcd-network.yml`
      (only if you've elected to use `cf-deployment/operations/rename-network.yml`)

1. In the next deployment,
omit only `opt-out-of-cf-syslog-drain-release-for-transition.yml` while keeping:
    - `keep-etcd-for-transition.yml`
    - `enable-doppler-announce.yml`
    - `keep-syslog-drain-binder-for-transition.yml`
    - optional: `rename-etcd-network.yml`
      (only if you've elected to use `cf-deployment/operations/rename-network.yml`)

1. In the next deployment,
omit both `enable-doppler-announce.yml`
and `keep-syslog-drain-binder-for-transition.yml` while keeping:
    - `keep-etcd-for-transition.yml`
    - optional: `rename-etcd-network.yml`
      (only if you've elected to use `cf-deployment/operations/rename-network.yml`)

1. In subsequent deployments, 
omit the remaining transition operations.
