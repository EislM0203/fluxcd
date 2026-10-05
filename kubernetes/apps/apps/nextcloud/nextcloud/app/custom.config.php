<?php
$CONFIG = array (
  // replaces the installer's list: Euro-Office calls back on the Service name (StorageUrl)
  'trusted_domains' => array (
    'next.cloud.traunseenet.com',
    'nextcloud.apps.svc.cluster.local',
  ),
  // always use the current CNPG app secret, so a restored config.php can't carry a stale password
  'dbhost' => getenv('POSTGRES_HOST'),
  'dbname' => getenv('POSTGRES_DB'),
  'dbuser' => getenv('POSTGRES_USER'),
  'dbpassword' => getenv('POSTGRES_PASSWORD'),
  'eurooffice' => array (
    'DocumentServerUrl' => 'https://office.cloud.traunseenet.com/',
    'DocumentServerInternalUrl' => 'http://eurooffice.apps.svc.cluster.local/',
    'StorageUrl' => 'http://nextcloud.apps.svc.cluster.local/',
    'jwt_secret' => getenv('EUROOFFICE_JWT_SECRET'),
  ),
  'default_phone_region' => 'DE',
  'maintenance_window_start' => 1,
  'preview_imaginary_url' => 'http://nextcloud-imaginary',
  'enable_previews' => true,
  'preview_max_x' => 2048,
  'preview_max_y' => 2048,
  'enabledPreviewProviders' => array (
    'OC\Preview\Imaginary',
    'OC\Preview\ImaginaryPDF',
    'OC\Preview\BMP',
    'OC\Preview\Krita',
    'OC\Preview\MarkDown',
    'OC\Preview\MP3',
    'OC\Preview\OpenDocument',
    'OC\Preview\TXT',
    'OC\Preview\XBitmap',
  ),
);
