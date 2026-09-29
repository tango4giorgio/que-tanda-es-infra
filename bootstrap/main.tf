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
