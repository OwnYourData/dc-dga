USE_CASES = {
  'eeg_altruism' =>
      { title: 'EEG Altruism',
        D2A_schema: 'D2Aeeg',
        d2a_edit: 'd2a_edit',
        d2a_transform: 'D2Aeeg',
        D3A_schema: 'D3Aeeg',
        d3a_edit: 'd3a_edit',
        da_reasoner: 'OntologyEEG',
        contract_transfrom: 'EegConsentForm',
        contract_schema: 'EegConsentForm',
        consent_schema: 'EEGconsent',
        consent_tranform: 'EEGconsent' },
  'api_sharing' =>
      { title: 'API Sharing',
        D2A_schema: 'D2AapiSharing',
        d2a_edit: 'd2a_edit',
        d2a_transform: 'D2AapiSharing',
        D3A_schema: 'D3AapiSharing',
        d3a_edit: 'd3a_edit',
        da_reasoner: 'OntologyAPIsharing',
        pod_url: 'https://api-sharing.go-data.at',
        pod_key: 'Nm6tgc_nKtmfOjRPWDduzyVl2BBVTmB9cK9qjN2tx5Y',
        pod_secret: 'xT-NnKfO0ZnuR7ZIpPOMjyN5SYD16Ir0SmHOIrsjkV0',
        contract_transfrom: 'ApiSharingConsentForm',
        contract_schema: 'ApiSharingConsentForm',
        consent_schema: 'ApiSharingConsent',
        consent_tranform: 'ApiSharingConsent'
      }
}.freeze