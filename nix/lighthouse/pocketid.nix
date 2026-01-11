{ config, pkgs, ... }:

let
  idpDomain = "id.traunseenet.com";
in {
  services.pocket-id = {
    enable = true;
    settings = {
      APP_URL = "https://${idpDomain}";
      HOST    = "127.0.0.1";
      PORT    = 1411;
      TRUST_PROXY = true;
      ENCRYPTION_KEY_FILE = "/var/lib/pocket-id/encryption.key";
      UI_CONFIG_DISABLED = true;
      ANALYTICS_DISABLED = true;
      # DB_PROVIDER default "sqlite"; data stored in /var/lib/pocket-id (no extra config needed).
    };
  };
}