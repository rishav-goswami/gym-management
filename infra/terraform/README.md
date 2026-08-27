# Firebase project infrastructure

This Terraform root provisions a **new** Firebase environment: the Google Cloud
project, billing link, required APIs, Firebase registration, Firestore with
deletion protection and optional PITR, Authentication providers,
Android/Apple/web apps, two Hosting sites, and an optional daily Firestore backup schedule. The Firebase
CLI owns rules, indexes, and TTL fields so there is only one writer for them.

Terraform state is deliberately excluded from Git because it can contain
sensitive values. Use an encrypted, access-controlled remote backend for team or
production use. The provider lock file is committed for repeatability.

## Provision a new environment

```sh
gcloud auth application-default login
cp infra/terraform/terraform.tfvars.example infra/terraform/production.tfvars
cp infra/terraform/backend.hcl.example infra/terraform/backend.hcl
# Edit production.tfvars. Never commit it.
# Create the backend bucket once in an account you control, enable object
# versioning, and edit the ignored backend.hcl.
terraform -chdir=infra/terraform init -backend-config=backend.hcl
terraform -chdir=infra/terraform plan -var-file=production.tfvars -out=production.tfplan
terraform -chdir=infra/terraform apply production.tfplan
terraform -chdir=infra/terraform output post_apply_commands
```

Run the printed Hosting target commands, generate the FlutterFire client
configuration for the new app IDs, and then deploy the repository-managed layer:

```sh
npx firebase deploy --project YOUR_PROJECT_ID \
  --only firestore:rules,firestore:indexes,storage,functions,remoteconfig
npm run migrate:data -- --project YOUR_PROJECT_ID --dry-run
npm run migrate:data -- --project YOUR_PROJECT_ID --confirm YOUR_PROJECT_ID
```

Build and deploy each Hosting target only after its Firebase options and App
Check keys point to that environment.

## Existing environments

Do not run `terraform apply` against an existing project with an empty state;
Terraform will try to create resources that already exist. Import each existing
resource first using the import identifiers in the official Google provider
documentation, review `terraform plan`, and accept the project only when the plan
shows no destructive replacement. The current `createmix-in` project remains
Firebase-CLI-managed until that explicit adoption is completed.

Never use `terraform destroy` for a live environment. Project deletion is
prevented and app/site/database resources are configured to be abandoned rather
than deleted where the provider supports that behavior.
