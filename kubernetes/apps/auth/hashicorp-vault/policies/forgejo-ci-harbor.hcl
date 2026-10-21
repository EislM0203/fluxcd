# CI in traunseenet-lab, push to main /
# v* tags only (role harbor-push):
# read the Harbor robot, nothing else.
path "secret/data/ci/harbor" {
  capabilities = ["read"]
}
# The role sets token_no_default_policy, so the job needs this explicitly to
# revoke its own token after docker login.
path "auth/token/revoke-self" {
  capabilities = ["update"]
}