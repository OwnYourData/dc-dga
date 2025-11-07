# General: 0
EVENT_INCOMPLETE_OP = 101

# User Management: 1000
EVENT_LOGIN_FAILURE = 1000
EVENT_NEW_USER = 1001
EVENT_UPDATE_USER = 1002
EVENT_IDA_START = 1010
EVENT_IDA_LOGIN = 1011
EVENT_WALLET_START = 1020
EVENT_WALLET_LOGIN = 1021
EVENT_LOGOUT = 1050

EVENT_SEND_EMAIL_VERIFICATION = 1100
EVENT_EMAIL_VERIFIED = 1101
EVENT_CONNECT_WALLET = 1110

EVENT_EXTERNAL_USER_REQUEST = 1200

# Assets: 2000
EVENT_D2A_INIT = 2000
EVENT_D2A_SAVE = 2001
EVENT_D2A_UPDATE = 2002
EVENT_D2A_SIGN = 2003
EVENT_ASSET_DELETE = 2010

# Data Catalog: 3000
EVENT_DATA_INIT = 3000
EVENT_DATA_DELETE = 3001
EVENT_D3A_SAVE = 3010
EVENT_D3A_SIGN = 3011

# Contracts: 4000
EVENT_CONTRACT_D2A = 4000
EVENT_CONTRACT_D3A = 4001
EVENT_CONSENT_RECORD = 4010
EVENT_CONSENT_DELETE = 4011

EVENT_DEFS = {
  'unknown_user'   => { type: EVENT_LOGIN_FAILURE,   msg: 'login failed with invalid "state"', 	         user: :bpk },
  'new_user'       => { type: EVENT_NEW_USER,        msg: 'new user account created on first login',     user: :bpk },
  'update_user'    => { type: EVENT_UPDATE_USER,     msg: 'user account updated on ID Austria login',    user: :bpk },
  'start_ida'      => { type: EVENT_IDA_START,       msg: 'initiate ID Austria login',                   user: :nil },
  'idaustria_login'=> { type: EVENT_IDA_LOGIN,       msg: 'login with ID Austria',                       user: :bpk },
  'start_wallet'   => { type: EVENT_WALLET_START,    msg: 'initiate wallet login',                       user: :nil },
  'wallet_login'   => { type: EVENT_WALLET_LOGIN,    msg: 'login with wallet',                           user: :bpk },
  'logout'         => { type: EVENT_LOGOUT,          msg: 'logout',                                      user: :bpk },
  'send_email_verification' => { type: EVENT_SEND_EMAIL_VERIFICATION, msg: 'send email verification',    user: :bpk },
  'email_verified' => { type: EVENT_EMAIL_VERIFIED,  msg: 'email verified',                              user: :bpk },
  'connect_wallet' => { type: EVENT_CONNECT_WALLET,  msg: 'connect wallet',                              user: :bpk },
  'external_user_request' => { type: EVENT_EXTERNAL_USER_REQUEST, msg: 'send request for external user', user: :nil }, 
  'd2a_init'       => { type: EVENT_D2A_INIT,        msg: 'initialize new asset',                        user: :bpk },
  'd2a_save'       => { type: EVENT_D2A_SAVE,        msg: 'create new asset',                            user: :bpk },
  'd2a_update'     => { type: EVENT_D2A_UPDATE,      msg: 'update asset',                                user: :bpk },
  'd2a_sign'       => { type: EVENT_D2A_SIGN,        msg: 'sign asset',                                  user: :bpk },
  'asset_delete'   => { type: EVENT_ASSET_DELETE,    msg: 'delete asset',                                user: :bpk },
  'data_init'      => { type: EVENT_DATA_INIT,       msg: 'create new data catalog entry',               user: :bpk },
  'data_delete'    => { type: EVENT_DATA_DELETE,     msg: 'delete data catalog entry',                   user: :bpk },
  'd3a_save'       => { type: EVENT_D3A_SAVE,        msg: 'create new data request',                     user: :bpk },
  'contract_d2a'   => { type: EVENT_CONTRACT_D2A,    msg: 'create data sharing agreement',               user: :bpk },
  'd3a_sign'       => { type: EVENT_D3A_SIGN,        msg: 'sign data request',                           user: :bpk },
  'contract_d3a'   => { type: EVENT_CONTRACT_D3A,    msg: 'create data disclosure agreement',            user: :bpk },
  'consent_record' => { type: EVENT_CONSENT_RECORD,  msg: 'create consent record',                       user: :bpk },
  'contract_delete'=> { type: EVENT_CONSENT_DELETE,  msg: 'delete contract',                             user: :bpk },
  'operation_not_completed' => { type: EVENT_INCOMPLETE_OP, msg: 'operation not completed',              user: :bpk }
}.freeze

