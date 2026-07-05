# Bootstrap

During the initial setup of `homelab`, the state file needs to be created in an
S3-compatible bucket. Ideally these instructions will never need to be used
again for this repo, but these instructions exist in case of emergency.

## 1. Create the Linode Object Storage state bucket

In the Linode (Akamai) Cloud dashboard, create an Object Storage bucket
`homelab-tfstate` on the `us-lax-4` endpoint. If you use a different region,
update `region` and the `endpoints.s3` URL in `terraform/backend.tf` to match.

## 2. Create the Linode Object Storage access key

Create an Object Storage access key limited to the `homelab-tfstate`
bucket. This yields an **Access Key** + **Secret Key**—the S3-compatible creds
the backend uses.

## 3. Authenticate the AWS CLI tool

```sh
aws configure --profile homelab

# AWS Access Key ID      -> <Linode access key>
# AWS Secret Access Key  -> <Linode secret key>
# Default region name    -> us-lax-4 (or whatever region the bucket was created in)
# Default output format  -> json
```

## 4. Enable object versioning

Then enable object versioning. The Linode dashboard does not support this, 
so use the S3 API.

```sh
aws s3api put-bucket-versioning \
  --profile homelab \
  --bucket homelab-tfstate \
  --versioning-configuration Status=Enabled \
  --endpoint-url https://us-lax-4.linodeobjects.com \
  --region us-lax-4
```

Verify it took effect:

```sh
aws s3api get-bucket-versioning \
  --profile homelab \
  --bucket homelab-tfstate \
  --endpoint-url https://us-lax-4.linodeobjects.com \
  --region us-lax-4
```

The output should be `{"Status": "Enabled"}`.

## 5. Create the Proxmox API identity (on Cerebro)

Create a dedicated role, user, and API token scoped to what the `bpg/proxmox`
provider needs. Run on the host:

```sh
pveum role add Terraform -privs "\
Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit \
Pool.Allocate Pool.Audit Sys.Audit Sys.Console Sys.Modify SDN.Use \
VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit \
VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options \
VM.Migrate VM.PowerMgmt VM.Snapshot \
User.Modify Group.Allocate Realm.AllocateUser Mapping.Audit Mapping.Modify Mapping.Use"

pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role Terraform

pveum user token add terraform@pve tf --privsep 0
```

The full token value for the Proxmox API key in `.env.sh` is
`terraform@pve!tf=<uuid-output-by-above-command>`.

6. Upload SSH key to Cerebro

`bgp/proxmox` needs SSH access for some operations, so upload your SSH key to
the server:

```sh
ssh-copy-id -i ~/.ssh/id_file.pub ssh-copy-id root@cerebro.lan
```

## 6. Generate the state-encryption passphrase

Generate a strong random passphrase (e.g. `openssl rand -base64 32`). Store the
random passphrase in 1Password. Losing the passphrase makes the encrypted state
unrecoverable.

## 7. Local env file

Copy the template and fill in the values:

```sh
cp terraform/.env.sh.example terraform/.env.sh
```

Copy this working `.env.sh` file into 1Password.

## 8. Follow steps in README.md

The steps in README.md for deploying should now work.
