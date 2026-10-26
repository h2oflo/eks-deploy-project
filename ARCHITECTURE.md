# EKS Deploy Project

Terraform + GitHub Actions + ArgoCD. Everything in us-west-2.

## Flow

1. **terraform.yml** — push to main → plan → reviewer approves `production` env → apply. Builds VPC, EKS, Karpenter (chart + CRDs + NodePool), RDS.
2. **build.yml** — on `apps/backend-api/**` changes, builds amd64+arm64 image, pushes to ECR (`:latest`, `:sha`). Creates the repo on first run.
3. **argocd-bootstrap.yml** — manual, once. Helm-installs ArgoCD, which registers the Applications.
4. ArgoCD syncs from this repo after that. No manual helm.

```bash
curl http://backend.ojflores-primary.com/
# {"pod_name":"...","db_status":"connected","timestamp":"..."}
```

`db_status` = real Postgres connection, `SELECT 1`. Pod goes unready if the DB is down; ALB drops it.

## Layout

```
terraform/          VPC, EKS, Karpenter, RDS, S3 backend
apps/backend-api/   FastAPI app, Dockerfile, helm chart
argocd/             ArgoCD chart + app-of-apps
charts/             external-secrets, alb-controller, external-dns wrappers
.github/workflows/  terraform.yml, build.yml, argocd-bootstrap.yml
```

## Design notes

- Private subnets tagged `kubernetes.io/role/internal-elb` + `karpenter.sh/discovery` — ALB controller and Karpenter find subnets by tag, no IDs hardcoded.
- Karpenter: arm64-only Graviton, consolidation on, 30d expiry, pinned AL2023 AMI. NodePool applied by terraform (`kubectl_manifest`), drift fixed on next apply.
- Managed node group (2× m5.large) runs only the Karpenter controller, so the autoscaler doesn't manage its own node.
- RDS postgres, encrypted, private. Master password in Secrets Manager (`manage_master_user_password`).
- App: FastAPI, `GET /` → pod name, db status, timestamp. 2 replicas.
- ESO, ALB controller, external-dns deployed by ArgoCD like any other app.

## Known gaps

- EKS endpoint public, no CIDR allowlist.
- CI role = AdministratorAccess.
- IRSA role ARNs in chart values are `<update-me>`; roles not in terraform yet.
- ESO installed but app still fetches the DB secret itself (boto3). ExternalSecret not wired up.
- ArgoCD tracks `:latest`; `:sha` tags unused.
- RDS `skip_final_snapshot = true`.

## First-time setup

### 1. OIDC role for CI

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

cat > /tmp/gha-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": [
          "repo:h2oflo/eks-deploy-project:ref:refs/heads/main",
          "repo:h2oflo/eks-deploy-project:environment:production"
        ]
      }
    }
  }]
}
EOF

aws iam create-role \
  --role-name github-actions-terraform \
  --assume-role-policy-document file:///tmp/gha-trust.json

aws iam attach-role-policy \
  --role-name github-actions-terraform \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Two `sub` patterns needed — `environment: production` jobs get a different subject than `ref:refs/heads/main`. Missing the second = apply job can't assume the role.

### 2. State bucket

```bash
aws s3 mb s3://terraform-state-<ACCOUNT_ID> --region us-west-2
aws s3api put-bucket-versioning --bucket terraform-state-<ACCOUNT_ID> \
  --versioning-configuration Status=Enabled
```

Bucket must exist before `terraform init`.

### 3. GitHub approval gate

**Settings → Environments → `production` → Required reviewers.** Without it, `environment: production` approves itself.

## Usage

```bash
aws eks update-kubeconfig --region us-west-2 --name <cluster-name>
```

Names/settings in `terraform/variables.tf`.
