scope "(:locale)", :locale => /en|de/ do
    # UI ==========================

    # Welcome page ----------------
    root 'welcome#start'
    match '/start',        to: 'welcome#start',        via: 'get'
    match '/logout',       to: 'welcome#logout',       via: 'get'
    # redirecting to ID Austria
    match 'ida_redirect',  to: 'welcome#ida_redirect', via: 'post'

    # ID Austria redirect (coming from ID Austria)
    match '/id-austria',   to: 'welcome#idaustria',    via: 'get'    
    match '/id-austria',   to: 'welcome#ida_payload',  via: 'post'    

    # User Request
    match '/user-request',       to: 'welcome#user_request',        via: 'get'
    match 'submit_user_request', to: 'welcome#submit_user_request', via: 'post', as: 'submit_request'
    match '/onboard',            to: 'welcome#onboard',             via: 'get'

    # Asset page ------------------
    match '/assets',            to: 'asset#asset',    via: 'get'
    match '/assets/uc-soya',    to: 'asset#uc_soya',  via: 'get', as: 'asset_modal'
    match '/asset/delete/:id',  to: 'asset#delete',   via: 'post'
    match '/asset/:id/soya',    to: 'asset#soya',     via: 'get', as: 'asset_soya'
    match 'asset_d2a',          to: 'asset#d2a',      via: 'post'

    # Data Catalog page -----------
    match '/data',             to: 'data#data',        via: 'get'
    match '/data/soya',        to: 'data#soya',        via: 'get', as: 'data_soya'
    match '/data/delete',      to: 'data#delete',      via: 'post'
    match '/data/delete/:id',  to: 'data#delete',      via: 'post'
    match 'data_d3a',          to: 'data#d3a',         via: 'post'

    # Service Catalog page --------
    match '/services',         to: 'service#services', via: 'get'

    # Contract page ---------------
    match '/contracts',         to: 'contract#contracts',    via: 'get'
    match '/contract/soya',     to: 'contract#soya',         via: 'get', as: 'contract_soya'
    match '/contract/soya_url', to: 'contract#soya_url',     via: 'get'
    match '/contract/delete',   to: 'contract#delete',       via: 'post'
    match '/contract/pdf',      to: 'contract#pdf_download', via: 'get', as: 'contract_pdf'

    # Log page --------------------
    match '/logs',         to: 'log#logs',             via: 'get'
    match '/event/:id',    to: 'log#object',           via: 'get', as: 'object_event'

    # Info page -------------------
    match '/info',         to: 'info#info',            via: 'get'
    match '/faq',          to: 'info#faq',             via: 'get'
    match '/faq/:id',      to: 'info#article',         via: 'get', as: 'article'

    # Profile page ----------------
    match '/settings',            to: 'profile#settings',             via: 'get'
    match 'email_update',         to: 'profile#email_update',         via: 'post'
    match '/verify',              to: 'welcome#verify_email',         via: 'get'
    match 'sign_sd_dataprovider', to: 'profile#sign_sd_dataprovider', via: 'post'

    match '/sigbox/success',      to: 'profile#sigbox_success',       via: 'get'
    match '/sigbox/failure',      to: 'profile#sigbox_failure',       via: 'get'

    # issue credential
    match '/didfc/.well-known/openid-credential-issuer', to: 'oid4vc#credential_config', via: 'get'
    match '/didfc/token',                                to: 'oid4vc#credential_token',  via: 'post'
    match '/didfc/credentials',                          to: 'oid4vc#credentials',       via: 'post'

    # Administrative functions ----
    match '/check',        to: 'admin#check',        via: 'get'
    match '/check_signed', to: 'admin#check_signed', via: 'get'

    # Wallet ==========================
    # Login ---------------------------
    match 'continue',                   to: 'welcome#continue',     via: 'post'
    match '/wallet/auth-requests/:id',  to: 'oid4vc#auth_request',  via: 'get'
    match '/wallet/auth-responses/:id', to: 'oid4vc#auth_response', via: 'post'

    # Sign VC for D2A -----------------
    match '/d2a-sign/.well-known/openid-credential-issuer', to: 'oid4vc#d2a_sign',         via: 'get'
    match '/d2a-sign/token',                                to: 'oid4vc#d2a_token',        via: 'post'
    match '/d2a-sign/credentials',                          to: 'oid4vc#d2a_credential',   via: 'post'
    match '/d2a-sign/notification',                         to: 'oid4vc#d2a_notification', via: 'post'
    match 'd2a_signed',                                     to: 'admin#d2a_signed',        via: 'post'

    # Sign VC for D3A -----------------
    match '/d3a-sign/.well-known/openid-credential-issuer', to: 'oid4vc#d3a_sign',         via: 'get'
    match '/d3a-sign/token',                                to: 'oid4vc#d3a_token',        via: 'post'
    match '/d3a-sign/credentials',                          to: 'oid4vc#d3a_credential',   via: 'post'
    match '/d3a-sign/notification',                         to: 'oid4vc#d3a_notification', via: 'post'
    match 'd3a_signed',                                     to: 'admin#d3a_signed',        via: 'post'

    # Sign VC for Self-Declaration -----------------
    match '/sddp-sign/.well-known/openid-credential-issuer', to: 'oid4vc#sddp_sign',         via: 'get'
    match '/sddp-sign/token',                                to: 'oid4vc#sddp_token',        via: 'post'
    match '/sddp-sign/credentials',                          to: 'oid4vc#sddp_credential',   via: 'post'
    match '/sddp-sign/notification',                         to: 'oid4vc#sddp_notification', via: 'post'
    match 'sddp_signed',                                     to: 'admin#sddp_signed',        via: 'post'

end