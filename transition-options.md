# Transition Options

Depending on your
current deployment of Cloud Foundry,
there may be componenet differences
between cf-release and cf-deployment.

There are some decisions to can make
regarding when and how to introduce
the new CF components that cf-deployment
comprises.

- [Decide How to Handle the Routing Release](#routing-release)
- [Decide How to Handle the CF Networking Release](#cf-networking-release)
- [Decide How to Handle the Application Syslog Drain Infrastructure](#syslog-drain)

## <a id="routing-release"></a> Decide How to Handle the Routing Release

If you have not yet deployed `routing-release`
in your existing cf-release based deployment,
you must decide
whether you want to introduce the
routing components
as part of your transition,
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
as part of your transition,
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

1. In the transition deployment, use
    - `keep-etcd-for-transition.yml`
    - `keep-syslog_drain_binder-for-transition.yml`
    - optional: `rename-etcd-network.yml`
      (only if you've elected to use `cf-deployment/operations/rename-network.yml`)

1. In subsequent deployments,
omit the transition operations.

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

1. In the transition deployment:
    - `keep-etcd-for-transition.yml`
    - `keep-syslog_drain_binder-for-transition.yml`
    - `opt-out-of-cf-syslog-drain-release-for-transition.yml`
    - optional: `rename-etcd-network.yml`
      (only if you've elected to use `cf-deployment/operations/rename-network.yml`)

1. In the next deployment:
    - `keep-etcd-for-transition.yml`
    - `keep-syslog_drain_binder-for-transition.yml`
    - optional: `rename-etcd-network.yml`
      (only if you've elected to use `cf-deployment/operations/rename-network.yml`)

1. In subsequent deployments, 
omit the transition operations.
