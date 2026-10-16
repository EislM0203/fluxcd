edge_wg_home_public_key = "YePzAZjvn6QWTNuvhGfIdqf0StvCRMjfmPvGGpQqHFk="
# Optional, strictest CAA pinning — NOT while lighthouse/Pangolin still serves *.cloud
# names (its own ACME account would be locked out; see variables.tf):
# acme_account_uri = "<kubectl get clusterissuer letsencrypt-prod -o jsonpath='{.status.acme.uri}'>"
