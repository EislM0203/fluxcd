{
  security.acme = {
    acceptTerms = true;
    defaults.email = "markuseisl@pm.me";
    defaults.server = "https://acme-v02.api.letsencrypt.org/directory";
    certs."traunseenet.com" = {
      dnsProvider = "cloudflare";
      credentialsFile = "/var/lib/acme/cloudflare-api.ini";
      domain = "*.traunseenet.com";
      extraDomainNames = [
        "traunseenet.com"
        "*.cloud.traunseenet.com"
        "*.local.traunseenet.com"
      ];
      group = "haproxy";
      postRun = ''
        cd /var/lib/acme/traunseenet.com
        cat "key.pem" "fullchain.pem" > "combined.pem"
        chown acme:haproxy combined.pem
        chmod 640 combined.pem
        systemctl reload haproxy.service || true
      '';
    };
  };
}