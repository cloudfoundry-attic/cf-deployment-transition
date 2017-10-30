# How to transition

This document is designed
to guide a deployer
through a transition
from `cf-release` to `cf-deployment`
step-by-step.
For additional details
about the transition in general,
consult the [README](README.md)

Please feel free
to reach out to us for assistance
on Slack
in the `#cf-deployment` channel
at https://cloudfoundry.slack.com.

0. [Satisfying prerequisites](#prerequisites)
1. [Extracting the `vars-store`](#vars-store-extraction)
1. [Choosing transition options](#transition-options)
1. [Deploying with necessary opsfiles](#transition-deployment)
1. [Removing `etcd`](#remove-etcd)
1. [Deleting the `diego` deployment](#delete-diego)
1. [Deleting the `routing` deployment](#delete-routing)

## <a id="prerequisites"></a> Step 0: Satisfying prerequisites

Please see the [prerequisites section of the README](README.md#prerequisites).
This guide assumes that
all of the listed prerequisites
have been satisfied.

## <a id="vars-store-extraction"></a> Step 1: Extracting the `vars-store`

In order for the transition
to work seamlessly,
credentials from
your existing `cf-release` deployment
must be extracted
for use in transitioning to `cf-deployment`.
We accomplish this using a
`vars-store`, which is simply a `.yml` file
that contains key-value pairs
used by the `bosh` cli
to interpolate into the `cf-deployment` manifest.
To extract the `vars-store`,
run `extract-vars-store-from-manifest.sh`
with the following arguments:

| Parameter | Value |
| --- | --- |
| `--ca-keys` | CA keys file in the format described [here](README.md#ca-keys) |
| `--cf-manifest` | Your `cf-release` manifest |
| `--diego-manifest` | Your `diego` manifest |

This will write a
`vars-store` file named `deployment-vars.yml`
to the current directory.

If you have
`cf-networking-release`, `routing-release`, or `locket` deployed,
you may need to provide
optional flags
to extract their credentials
from the appropriate manifests:

| Flag | Additional credentials extracted |
| --- | --- |
| `N` | `cf-networking-release` |
| `r` | `routing-release` |
| `Q` | `locket` |

If you do not extract credentials properly,
they will be **regenerated**
when you deploy `cf-deployment`.
This may lead to downtime,
failed deployment,
or other issues.

## <a id="transition-options"></a> Step 2: Choosing transition options

Determine which
optional opsfiles
you need to include
based on your requirements:
[Transition Options](transition-options.md)

## <a id="transition-deployment"></a> Step 3: Deploying with necessary opsfiles

There are differences between
`cf-release` and `cf-deployment`
that would lead to disruption,
so we have provided opsfiles
to minimize changes during the transition.

In `cf-deployment-transition`:

| Name | Purpose | Required variables |
| --- | --- | --- |
 [`cfr-to-cfd.yml`](cfr-to-cfd.yml) |  `cf-deployment` places jobs in `instance_groups` that scale similarly.  However, these are different from where they exist in `cf-release`.  Therefore, this opsfile tells `bosh` to migrate the jobs from the new to the old `instance_groups`. | none |
| [`keep-etcd-for-transition.yml`](keep-etcd-for-transition.yml) | `cf-deployment` no longer uses `etcd`, but `cf-release` still requires it.  This opsfile keeps a single `etcd` instance for the transition.  Once the transition has been performed, `etcd` will be deleted. | `etcd_static_ips`: (Array) an array with a single entry - the IP address of the current `etcd_z2` instance. |

In `cf-deployment`:

| Name | Purpose | Required variables |
| --- | --- | --- |
| [`operations/legacy/keep-static-ips.yml`](https://github.com/cloudfoundry/cf-deployment/blob/master/operations/legacy/keep-static-ips.yml) | Holds consul and nats instances at a static IP address. | `consul_static_ips`: (Array) the IPs of the current `consul` instances.<br />`nats_static_ips`: (Array) the IPs of the current `nats` instances. |
| [`operations/legacy/keep-original-internal-usernames.yml`](https://github.com/cloudfoundry/cf-deployment/blob/master/operations/legacy/keep-original-internal-usernames.yml) | Maintains operator-provided usernames. | Provides ability to set (String) values for `properties.nats.user`, `properties.cc.staging_upload_user`, `properties.router.status.user` |
| [`operations/set-bbs-active-key.yml`](https://github.com/cloudfoundry/cf-deployment/blob/master/operations/set-bbs-active-key.yml) | Maintains current `bbs` active encryption key. | Sets the active key label to the value of `diego_bbs_active_key_label`, which is extracted from the `diego-release`-based manifest in step 1. |

We will assume for
this guide
that you are deploying to `aws`,
using `s3` for your blobstore,
and using `rds` for your databases.
To enable these features
with `cf-deployment`,
the opsfiles needed are
`aws.yml`, `use-s3-blobstore.yml`, and `use-external-dbs.yml`
(see [opsfile documentation](https://github.com/cloudfoundry/cf-deployment/tree/master/operations#ops-files)).
Also of note is that `cf-deployment`
has one required variable: `system_domain`.

(For other IaaSes
and datastore setups,
you'll need to use other ops-files,
or potentially write your own,
to achieve similar changes.
cf-deployment includes ops-files
for [Azure](https://github.com/cloudfoundry/cf-deployment/blob/master/operations/aws.yml)
and [Openstack](https://github.com/cloudfoundry/cf-deployment/blob/master/operations/openstack.yml),
while GCP and vSphere work without any ops-files.
Whatever your blobstore and database solutions are,
be sure to account for those as well.)

A typical transition deployment `bosh deploy` command looks like:
```
bosh deploy -d cf \
-v system_domain=your.system.domain \
--vars-store=deployment-vars.yml \
-o cf-deployment/operations/aws.yml \
-o cf-deployment/operations/use-external-dbs.yml \
-l rds-vars.yml \
-o cf-deployment/operations/use-s3-blobstore.yml \
-l s3-vars.yml \
-o cf-deployment/operations/legacy/keep-static-ips.yml \
-l static-ip-vars.yml \
-o cf-deployment-transition/keep-etcd-for-transition.yml \
-l etcd-ips.yml \
-o cf-deployment/operations/set-bbs-active-key.yml \
-o cf-deployment-transition/cfr-to-cfd.yml \
cf-deployment/cf-deployment.yml
```

## <a id="remove-etcd"></a> Step 4: Removing `etcd`

Perform another `bosh deploy` command,
using most of the same arguments
as the transition deploy
but omitting the opsfiles
from `cf-deployment-transition`
which will delete the now-unnecessary `etcd` instance.
Future deployments
should continue to omit these arguments
as they were only used for the transition.

## <a id="delete-diego"></a> Step 5: Deleting the `diego` deployment

`cf-deployment` unifies `cf-release` and `diego-release`
into a single deployment
that includes `diego-cell` instances
and the `diego` control plane.
Once the transition deployment
is complete,
you can then delete your `diego-release` deployment.
The apps on the `cells` in that deployment
will be drained to the `diego-cell` instances
in the `cf-deployment` deployment.

The command for this is 
```
bosh -d <your-diego-deployment> delete-deployment
```

## <a id="delete-routing"></a> Step 6: Deleting the `routing` deployment

`cf-deployment` unifies `cf-release` and `routing-release`
into a single deployment
that includes the `routing-release` components.
Once the transition deployment
is complete,
you can then delete your `routing-release` deployment.

The command for this is
```
bosh -d <your-routing-deployment> delete-deployment
```
