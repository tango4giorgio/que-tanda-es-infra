data "aws_caller_identity" "current" {}

resource "aws_iam_user" "deployer" {
  name = var.deployer_user_name
  path = "/"
}

# Scoped to exactly what the main backend-infra configuration provisions today
# (lambda_get_game.tf, lambda_get_previews.tf, lambda_submit_feedback.tf, lambda_gateway.tf,
# api_gateway.tf, ssm.tf). Update this alongside any new resource type added
# to the main configuration, or `terraform apply` there will fail with an
# access-denied error using this user.
data "aws_iam_policy_document" "deployer" {
  # IAM roles/policies for the three Lambda functions (aws_iam_role,
  # aws_iam_role_policy, aws_iam_role_policy_attachment in lambda_*.tf).
  statement {
    sid = "IamRoleManagement"
    actions = [
      "iam:CreateRole",
      "iam:GetRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.resource_name_prefix}-*"
    ]
  }

  # Creating a Lambda function with one of the roles above requires
  # permission to pass that role to the Lambda service specifically.
  statement {
    sid       = "IamPassRoleToLambdaOnly"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.resource_name_prefix}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  # The three Lambda functions themselves (aws_lambda_function, aws_lambda_permission).
  statement {
    sid = "LambdaFunctionManagement"
    actions = [
      "lambda:CreateFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:DeleteFunction",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.resource_name_prefix}-*"
    ]
  }

  # CloudWatch log groups for the three Lambdas (aws_cloudwatch_log_group).
  statement {
    sid = "LogGroupManagement"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.resource_name_prefix}-*",
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.resource_name_prefix}-*:*",
    ]
  }

  # CloudWatch Logs does not support resource-level scoping for the list
  # operation Terraform uses during refresh; this is read-only.
  statement {
    sid       = "LogGroupDescribeReadOnly"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  # The SSM SecureString parameter storing the Supabase connection string (ssm.tf).
  statement {
    sid = "SsmParameterManagement"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:DeleteParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.resource_name_prefix}/*"
    ]
  }

  # API Gateway v2 APIs/routes/integrations/stages (api_gateway.tf). API IDs
  # are assigned at creation time, so they cannot be scoped further than the
  # service's own resource path; this is still limited to this AWS account
  # and region, not account-wide admin.
  statement {
    sid = "ApiGatewayV2Management"
    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE",
    ]
    resources = [
      "arn:aws:apigateway:${var.aws_region}::/apis",
      "arn:aws:apigateway:${var.aws_region}::/apis/*",
    ]
  }

  # Used by the main configuration's data "aws_caller_identity" "current"
  # (lambda_get_game.tf) and by anyone verifying these credentials work.
  statement {
    sid       = "StsCallerIdentityReadOnly"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deployer" {
  name        = "${var.resource_name_prefix}-deployer"
  description = "Least-privilege permissions to run the backend-infra Terraform configuration for ${var.resource_name_prefix}."
  policy      = data.aws_iam_policy_document.deployer.json
}

resource "aws_iam_user_policy_attachment" "deployer" {
  user       = aws_iam_user.deployer.name
  policy_arn = aws_iam_policy.deployer.arn
}

# Long-lived access key for local/CLI use. Rotate periodically
# (`terraform taint aws_iam_access_key.deployer` then `terraform apply`
# generates a replacement) and never commit the generated secret.
resource "aws_iam_access_key" "deployer" {
  user = aws_iam_user.deployer.name
}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_actions_deployer" {
  name               = "${var.resource_name_prefix}-github-actions-deployer"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

resource "aws_iam_role_policy_attachment" "github_actions_deployer" {
  role       = aws_iam_role.github_actions_deployer.name
  policy_arn = aws_iam_policy.deployer.arn
}

# Dedicated Supabase project used only to host the Postgres database that
# stores Terraform state for the main backend-infra configuration (via its
# "pg" backend). It must be a separate project from the application's own
# (created by that configuration's supabase_project.catalogue), since the
# state backend must exist before Terraform can create anything else.
resource "random_password" "tfstate_database" {
  length  = 32
  special = true
}

resource "supabase_project" "tfstate" {
  organization_id   = var.supabase_organization_id
  name              = var.tfstate_project_name
  database_password = random_password.tfstate_database.result
  region            = var.supabase_region
  # State storage only; no application workload runs against this project's
  # database, so the smallest free-tier compute size is sufficient.
  instance_size = "nano"

  lifecycle {
    prevent_destroy = true
  }

  timeouts {
    create = "30m"
    update = "30m"
  }
}

# Connection string for Terraform's "pg" backend. Uses the Supavisor pooler
# in session mode (port 5432, not the transaction-mode port 6543 used for
# the application's own runtime connections) because the pg backend relies
# on Postgres advisory locks for state locking, and those locks do not
# survive PgBouncer/Supavisor transaction pooling. Session mode also works
# over IPv4 without the paid add-on that direct (non-pooled) connections
# require.
locals {
  tfstate_database_url = format(
    "postgresql://%s:%s@aws-0-%s.pooler.supabase.co:5432/postgres?sslmode=require",
    urlencode("postgres.${supabase_project.tfstate.id}"),
    urlencode(random_password.tfstate_database.result),
    var.supabase_region,
  )
}
