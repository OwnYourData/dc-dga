ISSUER_HOST = 'https://my.go-data.at'
CREDENTIAL_DID_PATH = "/didfc"
CREDENTIAL_DID_TYPE = "DID-FlexCo Credential"
AUTH_REQUEST_URI  = '/wallet/auth-requests/'
AUTH_RESPONSE_URI = '/wallet/auth-responses/'

CREDENTIAL_D2A_TYPE = "D2aCredential"
CREDENTIAL_D3A_TYPE = "D3aCredential"
CREDENTIAL_SDDP_TYPE = "SdDpCredential"
D2A_SIGNING_PATH = "/d2a-sign"
D3A_SIGNING_PATH = "/d3a-sign"
SDDP_SIGNING_PATH = "/sddp-sign"

SOYA_REPO_HOST = 'https://soya.ownyourdata.eu'
SOYA_FORM_HOST = 'https://soya-form.ownyourdata.eu'
SOYA_WEBCLI_HOST = 'https://soya-web-cli.ownyourdata.eu'
SOYA_WEBCLI_API_PREFIX = '/api/v1/'

REASONER_URL = 'https://reasoner.go-data.at/api/match'

UNIT_ALIASES = {
  # years
  'year'    => :years,    'years'    => :years,
  'jahr'    => :years,    'jahre'    => :years,    'jahren' => :years,

  # months
  'month'   => :months,   'months'   => :months,
  'monat'   => :months,   'monate'   => :months,   'monaten' => :months,

  # weeks
  'week'    => :weeks,    'weeks'    => :weeks,
  'woche'   => :weeks,    'wochen'   => :weeks,

  # days
  'day'     => :days,     'days'     => :days,
  'tag'     => :days,     'tage'     => :days,     'tagen' => :days
}.freeze

SIGBOX_HOST = 'https://sigbox.go-data.at'