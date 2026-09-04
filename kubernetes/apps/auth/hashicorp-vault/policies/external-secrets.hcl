# external-secrets: read-only on the KV v2 data and metadata paths.
# Add "create", "update", "delete" here if you ever use PushSecret.
path "secret/data/*" {
  capabilities = ["read"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list"]
}
