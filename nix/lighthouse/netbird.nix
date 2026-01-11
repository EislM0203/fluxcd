{
  lib,
  pkgs,
  ...
}: let
  cfg = {
    domain = "netbird.traunseenet.com";
    clientID = "d1d8dc55-d79f-4bf5-889d-d7a465efd72d";
    backendID = "netbird";
    ssoDomain = "id.traunseenet.com";
    ssoURL = "https://${cfg.ssoDomain}";
    sso_openid_url = "${cfg.ssoURL}/.well-known/openid-configuration";
    coturnPasswordPath = "/var/lib/netbird/turn_password";
    coturnSalt = "/var/lib/netbird/coturn_salt";
    dataStoreEncryptionKeyPath = "/var/lib/netbird/data_store_key";
    apiTokenFile = "/var/lib/netbird/pocketid_api_token"; 
  };
  ingress = {
    https = 8443;
  };
  # source_path = "/var/lib/.restic_netbird";
  cert_path = "/var/lib/acme/traunseenet.com";
in {
  # systemd.services.netbird-restore-data = {
  #   serviceConfig.Type = "oneshot";
  #   requiredBy = [
  #     "netbird-management.service"
  #     "netbird-signal.service"
  #     "coturn.service"
  #     "nginx.service"
  #   ];
  #   before = [
  #     "netbird-management.service"
  #     "netbird-signal.service"
  #     "coturn.service"
  #     "nginx.service"
  #   ];
  #   preStart = ''
  #     until [ -f ${source_path} ]; do sleep 1; done
  #   '';
  #   script = ''
  #     source ${source_path}
  #     ${pkgs.restic}/bin/restic restore latest --target /
  #     cp /var/lib/netbird-mgmt/coturnpass.key /var/lib/coturnpass.key
  #   '';
  # };

#  systemd.services.nginx-wait-for-cert = {
 #   serviceConfig.Type = "oneshot";
  #  requiredBy = [ "nginx.service" ];
   # before = [ "nginx.service" ];
#    script = ''
 #     usermod -aG haproxy nginx
   # '';
  #};
  users.users.nginx.extraGroups = [ "haproxy" ];
  services.nginx.virtualHosts."netbird.traunseenet.com" = lib.mkMerge [
    {
      forceSSL = true;
      sslCertificate = "${cert_path}/fullchain.pem";
      sslCertificateKey = "${cert_path}/key.pem";
      listen = [{
        addr = "127.0.0.202";
        ssl = true;
        port = ingress.https;
      }];
    }
  ];

  services.netbird.server = {
    domain = cfg.domain;
    enable = true;
    enableNginx = true;

    signal.metricsPort = 9092;

    coturn = {
      enable = true;
      passwordFile = cfg.coturnPasswordPath;
    };

    dashboard = {
      settings = {
        AUTH_AUTHORITY = cfg.ssoURL;
        AUTH_AUDIENCE = cfg.clientID;
        AUTH_CLIENT_ID = cfg.clientID;
        AUTH_SUPPORTED_SCOPES = "openid profile email groups";
        USE_AUTH0 = false;
      };
    };

    management = {
      oidcConfigEndpoint = cfg.sso_openid_url;
      metricsPort = 9093;
      settings = {
        DataStoreEncryptionKey._secret = cfg.dataStoreEncryptionKeyPath;

        TURNConfig = {
          Secret._secret = cfg.coturnSalt;
          Turns = [{
            Proto = "udp";
            URI = "turn:${cfg.domain}:3478";
            Username = "netbird";
            Password._secret = cfg.coturnPasswordPath;
          }];
        };

        HttpConfig = {
          AuthAudience = cfg.clientID;
          AuthIssuer = cfg.ssoURL;
          AuthKeysLocation = "${cfg.ssoURL}/.well-known/jwks.json";
          IdpSignKeyRefreshEnabled = true;
        };

        IdpManagerConfig = {
          ManagerType = "pocketid";
          ClientConfig = {
            Issuer = cfg.ssoURL;
            ClientID = cfg.backendID;
            GrantType = "client_credentials";
          };
          ExtraConfig = {
            ManagementEndpoint = "https://${cfg.ssoDomain}";
            ApiToken = {
              _secret = cfg.apiTokenFile;
            };
          };
        };

        DeviceAuthorizationFlow = {
          Provider = "none";
        };

        PKCEAuthorizationFlow = {
          ProviderConfig = {
            ClientID = cfg.clientID;
            Audience = cfg.clientID;
            TokenEndpoint = "${cfg.ssoURL}/api/oidc/token";
            AuthorizationEndpoint = "${cfg.ssoURL}/authorize";
            Scope = "openid profile email offline_access";
            UseIDToken = false;
          };
        };
      };
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ingress.https 8011 8012 8013 8014 9091 9092 9093 ];
    allowedUDPPorts = [ ingress.https 8011 8012 8013 8014 9091 9092 9093 ];
  };
}
