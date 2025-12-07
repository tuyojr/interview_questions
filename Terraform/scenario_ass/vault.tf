data "vault_kv_secret_v2" "infra_secrets" {
  count = var.use_vault_secrets ? 1 : 0
  mount = var.vault_kv_mount
  name  = var.vault_infra_secret_path
}

data "vault_kv_secret_v2" "db_secrets" {
  count = var.use_vault_secrets ? 1 : 0
  mount = var.vault_kv_mount
  name  = var.vault_db_secret_path
}

data "vault_kv_secret_v2" "ssh_secrets" {
  count = var.use_vault_secrets ? 1 : 0
  mount = var.vault_kv_mount
  name  = var.vault_ssh_secret_path
}

locals {
  bastion_public_key = var.use_vault_secrets ? (
    try(data.vault_kv_secret_v2.ssh_secrets[0].data["bastion_public_key"], var.bastion-pub-key)
  ) : var.bastion-pub-key

  db_username = var.use_vault_secrets ? (
    try(data.vault_kv_secret_v2.db_secrets[0].data["db_user"], "techcorp_user")
  ) : "techcorp_user"

  db_password = var.use_vault_secrets ? (
    try(data.vault_kv_secret_v2.db_secrets[0].data["db_password"], "")
  ) : ""

  db_name = var.use_vault_secrets ? (
    try(data.vault_kv_secret_v2.db_secrets[0].data["db_name"], "techcorp_db")
  ) : "techcorp_db"
}
