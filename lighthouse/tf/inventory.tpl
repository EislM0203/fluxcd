[pangolin]
${server_ip} ansible_user=${username} ansible_ssh_private_key_file=${ssh_private_key_path} ansible_python_interpreter=/usr/bin/python3

[pangolin:vars]
pangolin_base_domain=${pangolin_base_domain}
pangolin_dashboard_url=${pangolin_dashboard_url}
pangolin_admin_email=${pangolin_admin_email}
pangolin_secret=${pangolin_secret}
pangolin_admin_password=${pangolin_admin_password}
cloudflare_token=${cloudflare_token}
image_pangolin=${image_pangolin}
image_gerbil=${image_gerbil}
image_traefik=${image_traefik}
image_crowdsec=${image_crowdsec}
image_crowdsec_manager=${image_crowdsec_manager}
pocketid_base_url=${pocketid_base_url}
pocketid_client_id=${pocketid_client_id}
pocketid_client_secret=${pocketid_client_secret}
