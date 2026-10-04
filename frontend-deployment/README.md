# Frontend deployment

This Terraform root deploys the immutable prebuilt frontend artifact to an existing Vercel
project. It has isolated PostgreSQL-backed state under `frontend_deployment_state`, while the
workflow reads `gateway_endpoint` from the main infrastructure state and passes it as
`backend_gateway_url`.

The deployment expects the release archive to be extracted into:

```text
.vercel/output/static/
```

Terraform generates `.vercel/output/config.json`, including the same-origin `/api` rewrite,
then uploads the complete Build Output API directory using `vercel_prebuilt_project` and
`vercel_deployment`.
