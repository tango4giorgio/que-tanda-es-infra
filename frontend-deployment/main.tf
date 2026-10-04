locals {
  backend_gateway_url = trimsuffix(var.backend_gateway_url, "/")
}

resource "local_file" "vercel_config" {
  filename = "${path.module}/.vercel/output/config.json"
  content = jsonencode({
    version = 3
    routes = [
      {
        src  = "/api/(.*)"
        dest = "${local.backend_gateway_url}/$1"
      },
      {
        handle = "filesystem"
      },
      {
        src  = "/(.*)"
        dest = "/index.html"
      }
    ]
  })
}

data "vercel_prebuilt_project" "frontend" {
  path       = path.module
  depends_on = [local_file.vercel_config]
}

resource "vercel_deployment" "frontend" {
  project_id  = var.vercel_project_id
  team_id     = var.vercel_team_id
  files       = data.vercel_prebuilt_project.frontend.output
  path_prefix = data.vercel_prebuilt_project.frontend.path
  production  = true

  meta = {
    frontend_release_tag = var.frontend_release_tag
  }
}
