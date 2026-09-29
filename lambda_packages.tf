# Downloads the Lambda package .zip assets from a tagged GitHub Release of the backend
# repo (var.backend_release_repo / var.backend_release_tag), caching each by tag under
# .lambda-packages/ so repeat plans/applies for the same tag don't re-download. See
# scripts/fetch-lambda-package.sh for the download+hash logic.
locals {
  lambda_package_assets = {
    get_game        = "get_game.zip"
    get_previews    = "get_previews.zip"
    gateway         = "gateway.zip"
    submit_feedback = "submit_feedback.zip"
  }
}

data "external" "lambda_package" {
  for_each = local.lambda_package_assets

  program = ["${path.module}/scripts/fetch-lambda-package.sh"]

  query = {
    repo      = var.backend_release_repo
    tag       = var.backend_release_tag
    asset     = each.value
    cache_dir = "${path.module}/.lambda-packages"
  }
}
