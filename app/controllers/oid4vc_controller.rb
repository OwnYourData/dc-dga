class Oid4vcController < ApplicationController
    protect_from_forgery with: :null_session
    include ApplicationHelper
    include SessionsHelper

    def auth_request
        request_id = params.permit!["id"]
        client_ip = request.remote_ip

        @store = Store.find_by_key(request_id)
        if @store.nil?
            render json: {"error": "invalid request_id " + request_id.to_s},
                   status: 500
            return
        end
        item = @store.item
        action = item["action"] rescue nil
        if action.nil?
            render json: {"error": "invalid request_id " + request_id.to_s +  " (store-id: " + @store.id.to_s + ")"},
                   status: 500
            return
        end

        oid4vci_nonce = SecureRandom.uuid
        oid4vci_state = SecureRandom.uuid
        item["oid4vci_state"] = oid4vci_state

        oid4vci_jti = SecureRandom.uuid

        # get from Issuer
        issuer_did = ENV['ISSUER_DID'].strip
        sk_encoded = ENV['ISSUER_PWD'].strip
        key = Oydid.decode_private_key(sk_encoded).first
        public_key = key.public_key

        algorithm = 'ES256'
        header = {
            alg: algorithm,
            kid: issuer_did + '#0',
            typ: 'JWT'
        }

        if action == "oid4vc"
            oid4vci_registration = {
                id_token_signing_alg_values_supported: ['ES256'],
                request_object_signing_alg_values_supported: ['ES256'],
                response_types_supported: ['id_token'],
                scopes_supported: ['openid did_authn'],
                subject_types_supported: ['pairwise'],
                subject_syntax_types_supported: ['did:jwk'],
                vp_formats: {
                  jwt_vc: { alg: ['ES256'] },
                  jwt_vp: { alg: ['ES256'] }
                }
            }
            oid4vci_claims = {
                vp_token: {
                    presentation_definition: {
                        id: 'sphereon',
                        name: 'Sphereon',
                        purpose: 'You need to prove your Wallet Identity data',
                        input_descriptors: [{
                            id: 'SphereonWalletId',
                            name: 'Wallet Identity',
                            purpose: 'Checking your Sphereon Wallet information',
                            schema: [{uri: "https://sphereon-opensource.github.io/ssi-mobile-wallet/context/sphereon-wallet-identity-v1.jsonld"}, {uri: "Omzetbelasting"}, {uri: "OYD Credential"}]
                        }]
                      }
                }
            }

            payload = {
                iat: Time.now.to_i,
                exp: Time.now.to_i+120,
                response_type: 'id_token',
                response_mode: 'post',
                scope: 'openid',
                client_id: issuer_did,
                response_uri: ISSUER_HOST + AUTH_RESPONSE_URI + request_id,
                nonce: oid4vci_nonce,
                state: oid4vci_state,
                registration: oid4vci_registration,
                claims: oid4vci_claims,
                nbf: Time.now.to_i,
                jti: oid4vci_jti,
                iss: issuer_did,
                sub: issuer_did
            }

        elsif action == "oid4vc-wallet"
            payload = {
                iat: Time.now.to_i,
                exp: Time.now.to_i+120,
                response_type: 'vp_token',
                response_mode: 'direct_post',
                client_id_scheme: 'did',
                scope: 'openid',
                client_id: issuer_did,
                response_uri: ISSUER_HOST + AUTH_RESPONSE_URI + request_id,
                nonce: oid4vci_nonce,
                state: oid4vci_state,
                nbf: Time.now.to_i,
                jti: oid4vci_jti,
                iss: issuer_did,
                sub: issuer_did
            }

            payload["client_metadata"] = {
                id_token_signing_alg_values_supported: ['ES256'],
                request_object_signing_alg_values_supported: ['ES256'],
                response_types_supported: ['id_token', 'vp_token'],
                scopes_supported: ['openid did_authn'],
                subject_types_supported: ['pairwise'],
                subject_syntax_types_supported: ['did:jwk'],
                vp_formats: {
                    "vc+sd-jwt": {
                        "sd-jwt_alg_values": ["ES256"],
                        "kb-jwt_alg_values": ["ES256"],
                        alg: ['ES256']
                    },
                    "vp+sd-jwt": {
                        "sd-jwt_alg_values": ["ES256"],
                        alg: ['ES256']
                    },

                  jwt_vc_json: { alg: ['ES256'] },
                  jwt_vp_json: { alg: ['ES256'] },
                  jwt_vc: { alg: ['ES256'] },
                  jwt_vp: { alg: ['ES256'] },
                  ldp_vp: { alg: ['ES256'] }
                }
            }
            payload["presentation_definition"] = {
                id: 'sphereon',
                name: 'Wallet Identity',
                purpose: 'You need to prove your Wallet Identity data',
                format: {
                  "vc+sd-jwt": {}
                },                
                input_descriptors: [{
                    id: 'SphereonWalletId',
                    name: 'Wallet Identity',
                    purpose: 'Checking your Sphereon Wallet information',
                    schema: [{"uri": "SphereonWalletIdentityCredential"}]
                }]
            }
            @store.item = item
            @store.key = oid4vci_state.to_s
            @store.save

        elsif action == "oid4vp" # login
            oid4vci_registration = {
                id_token_signing_alg_values_supported: ['ES256'],
                request_object_signing_alg_values_supported: ['ES256'],
                response_types_supported: ['id_token'],
                scopes_supported: ['openid did_authn'],
                subject_types_supported: ['pairwise'],
                subject_syntax_types_supported: ['did:jwk', 'did:oyd'],
                vp_formats: {
                  jwt_vc: { alg: ['ES256'] },
                  jwt_vp: { alg: ['ES256'] } }
            }
            oid4vci_claims = {
                vp_token: {
                    presentation_definition: {
                        id: "DID_FlexCo",
                        "name": "DID FlexCo",
                        "purpose": "Verifikation eines DID FlexCo Zertifikats",
                        "input_descriptors": [{
                            "id": SecureRandom.uuid,
                            "name": "DID FlexCo Verifikation",
                            "purpose": "Abfrage eines DID FlexCo Zertifikats",
                            "schema": [{ "uri": CREDENTIAL_DID_TYPE }] }] } }
            }
            payload = {
                iat: Time.now.to_i,
                exp: Time.now.to_i+120,
                response_type: 'id_token',
                scope: 'openid',
                client_id: issuer_did,
                redirect_uri: ISSUER_HOST + AUTH_RESPONSE_URI + request_id,
                response_mode: 'post',
                nonce: oid4vci_nonce,
                state: oid4vci_state,
                registration: oid4vci_registration,
                claims: oid4vci_claims,
                nbf: Time.now.to_i,
                jti: oid4vci_jti,
                iss: issuer_did,
                sub: issuer_did
            }

            event_object = payload.merge(ip: client_ip)
            createEvent(
                bpk: nil, 
                event_str: 'start_wallet', 
                event_object: event_object )

        else
            render json: {"error": "unsupported action '" + action.to_s + "' in request_id " + request_id.to_s +  " (store-id: " + @store.id.to_s + ")"},
                   status: 500
            return

        end

        encoded_header = Base64.urlsafe_encode64(header.to_json, padding: false)
        encoded_payload = Base64.urlsafe_encode64(payload.to_json, padding: false)
        data_to_sign = "#{encoded_header}.#{encoded_payload}"
        jwt_digest = OpenSSL::Digest::SHA256.new
        asn1_signature = OpenSSL::ASN1.decode(key.dsa_sign_asn1(jwt_digest.digest(data_to_sign)))
        raw_signature = asn1_signature.value.map { |i| i.value.to_s(2).rjust(32, "\x00") }.join()
        encoded_signature = Base64.urlsafe_encode64(raw_signature, padding: false)
        token = "#{encoded_header}.#{encoded_payload}.#{encoded_signature}"

        render plain: token,
               status: 200
    end

    def auth_response
        session_id = params[:id]
        state = params[:state]
        vp_token = params[:vp_token]

        # only until second .
        data = JWT.decode(vp_token[/\A([^\.]*\.){1}[^\.]*/], nil, false)

        id_token = params[:id_token]
        vc = JWT.decode data.first["verifiableCredential"].first, nil, false rescue nil
        cs = vc.first["vc"]["credentialSubject"] rescue nil

        @store = Store.find_by_key(state)
        if @store.nil?
            @store = Store.find_by_key(session_id)
        end
        item = @store.item
        complete = item["complete-code"]
        item["holder-did"] = data.first["iss"]
        if !cs.nil?
            item["credentialSubject"] = cs
        end
        @store.item = item
        @store.key = complete
        @store.save

        render plain: '',
               status: 200
    end

    def credential_config
        issuer_host = ENV['ISSUER_HOST'] || ISSUER_HOST
        retVal = {
            "credential_issuer": issuer_host + CREDENTIAL_DID_PATH,
            "credential_endpoint": issuer_host + CREDENTIAL_DID_PATH + "/credentials",
            "token_endpoint": issuer_host + CREDENTIAL_DID_PATH + "/token",
            "display": [{
                "name": "DID FlexCo",
                "description": "DID Daten-Intermediär-Dienste FlexCo Credential"
            }],
            "credential_configurations_supported": {
                "DID_FlexCo": {
                  "format": "jwt_vc_json",
                  "cryptographic_binding_methods_supported": [
                    "did:jwk",
                    "did:oyd"
                  ],
                  "cryptographic_suites_supported": [
                    "ES256",
                    "EdDSA"
                  ],
                  "display": [
                    {
                      "name": "DID FlexCo Credential",
                      "description": "Credential issued by DID FlexCo",
                      "text_color": "#FBFBFB",
                      "background_color": "rgba(0, 0, 0, 0.2)",
                      "logo": {
                        "url": "https://www.ownyourdata.eu/wp-content/uploads/2025/08/did.png",
                        "alt_text": "DID logo"
                      },
                      "background_image": {
                        "url": "https://www.ownyourdata.eu/wp-content/uploads/2025/08/grant-ritchie.png",
                        "alt_text": "Skyscrapers background"
                      }
                    }
                  ],
                  "credential_definition": {
                    "type": [
                      "VerifiableCredential",
                      CREDENTIAL_DID_TYPE
                    ]
                  }
                }
            }
        }
        render json: retVal.to_json,
               status: 200
    end

    def credential_token
        preauth_code = params["pre-authorized_code"].to_s
        @store = Store.find_by_key(preauth_code)
        if @store.nil?
            @store = Store.new
            item = {}
        else
            item = @store.item
        end

        key = OpenSSL::PKey::EC.generate('prime256v1')
        algorithm = "ES256"
        header_fields = {
            alg: algorithm,
            typ: 'JWT'
        }
        issuer_host = ENV['ISSUER_HOST'] || ISSUER_HOST
        payload = {
            "iat": Time.now.utc.to_i,
            "exp": 300,
            "iss": issuer_host + CREDENTIAL_DID_PATH,
            "preAuthorizedCode": preauth_code
        }
        access_token = JWT.encode(payload, key, algorithm, header_fields)
        nonce = SecureRandom.alphanumeric(10)
        if item["nonce"].nil?
            item["nonce"] = nonce
            @store.item = item
        else
            nonce = item["nonce"]
        end
        @store.key = nonce
        @store.save

        retVal = {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": 86400,
            "c_nonce": nonce,
            "c_nonce_expires_in": 86400
        }
        render json: retVal,
               status: 200
    end

    def credentials
        proof = params['proof']
        jwt = proof['jwt']
        data = JWT.decode(jwt, nil, false)
        nonce = data.first["nonce"]
        @store = Store.find_by_key(nonce)
        item = @store.item
        if item.is_a?(String)
            item = JSON.parse(item) rescue {}
        end

        holder_did = data.first['iss']
        item['holder_did'] = holder_did
        expirationDate = (Time.now + (6 * 30 * 24 * 60 * 60)).to_i # Time.now.utc + 6.months

        @store.key = item['complete-code']
        @store.item = item
        @store.save

        @user = User.find_by_bpk(item['ida_user'].to_s)
        if !@user.nil?
            @user.did = holder_did
            @user.did_valid_until = Time.at(expirationDate)
            @user.save
        end

        issuer_did = ENV['DID_P256_ISSUER_DID']
        sk_encoded = ENV['DID_P256_ISSUER_KEY']
        key = Oydid.decode_private_key(sk_encoded).first

        content = {
            bpk: item["ida_user"].to_s,
            given_name: item["ida_given_name"].to_s,
            family_name: item["ida_family_name"].to_s,
            auth_time: item["ida_auth_time"].to_s
        }
        options = {}
        options[:issuer] = issuer_did
        options[:issuer_privateKey] = sk_encoded
        options[:holder] = holder_did
        options[:vc_type] = 'JsonWebSignature2020'
        credential, msg = Oydid.create_vc(content, options)
        credential["vc"]["@context"] = ["https://www.w3.org/2018/credentials/v1"]
        credential["vc"]["type"] = ["VerifiableCredential", CREDENTIAL_DID_TYPE]
        credential["vc"]["expirationDate"] = Time.at(expirationDate).strftime("%Y-%m-%dT%H:%M:%SZ")
        credential["exp"] = expirationDate

        algorithm = 'ES256'
        header = {
            alg: algorithm,
            kid: issuer_did + '#0',
            typ: 'JWT'
        }

        encoded_header = Base64.urlsafe_encode64(header.to_json, padding: false)
        encoded_payload = Base64.urlsafe_encode64(credential.to_json, padding: false)
        data_to_sign = "#{encoded_header}.#{encoded_payload}"
        jwt_digest = OpenSSL::Digest::SHA256.new
        asn1_signature = OpenSSL::ASN1.decode(key.dsa_sign_asn1(jwt_digest.digest(data_to_sign)))
        raw_signature = asn1_signature.value.map { |i| i.value.to_s(2).rjust(32, "\x00") }.join()
        encoded_signature = Base64.urlsafe_encode64(raw_signature, padding: false)
        jwt = "#{encoded_header}.#{encoded_payload}.#{encoded_signature}"

        retVal ={
          "format": "jwt_vc_json",
          "credential": jwt,
          "c_nonce": nonce,
          "c_nonce_expires_in": 86400
        }

        createEvent(
            bpk: item["ida_user"].to_s, 
            event_str: 'connect_wallet', 
            event_object: credential )

        render json: retVal,
               status: 200
    end

    def d2a_sign
        issuer_host = ISSUER_HOST
        retVal = {
            "credential_issuer": issuer_host + D2A_SIGNING_PATH,
            "credential_endpoint": issuer_host + D2A_SIGNING_PATH + "/credentials",
            "token_endpoint": issuer_host + D2A_SIGNING_PATH + "/token",
            "notification_endpoint": issuer_host + D2A_SIGNING_PATH + "/notification",
            "display": [{
                "name": "DID FlexCo",
                "description": "DID Daten-Intermediär-Dienste FlexCo Credential"
            }],
            "credentials_supported": [{
              "display": [{
                "name": "Data Agreement Credential",
                "description": "sign Data Agreement for data sharing",
                "text_color": "#000000",
                "background_color": "#FFFFFF"
              }],
              "id": "DaCredential",
              "types": [
                "VerifiableCredential",
                CREDENTIAL_D2A_TYPE
              ],
              "format": "jwt_vc_json",
              "cryptographic_binding_methods_supported": ['did:jwk', 'did:oyd'],
              "cryptographic_suites_supported": ["ES256"],
              "credential_subject_issuance": {
                "subject_proof_mode": "proof_replace",
                "notification_events_supported": ["credential_deleted_holder_signed"]
              }   
            }]
        }
        render json: retVal.to_json,
               status: 200
    end

    def d3a_sign
        issuer_host = ISSUER_HOST
        retVal = {
            "credential_issuer": issuer_host + D3A_SIGNING_PATH,
            "credential_endpoint": issuer_host + D3A_SIGNING_PATH + "/credentials",
            "token_endpoint": issuer_host + D3A_SIGNING_PATH + "/token",
            "notification_endpoint": issuer_host + D3A_SIGNING_PATH + "/notification",
            "display": [{
                "name": "DID FlexCo",
                "description": "DID Daten-Intermediär-Dienste FlexCo Credential"
            }],
            "credentials_supported": [{
              "display": [{
                "name": "Data Agreement Credential",
                "description": "sign Data Agreement for data disclosure",
                "text_color": "#000000",
                "background_color": "#FFFFFF"
              }],
              "id": "DaCredential",
              "types": [
                "VerifiableCredential",
                CREDENTIAL_D3A_TYPE
              ],
              "format": "jwt_vc_json",
              "cryptographic_binding_methods_supported": ['did:jwk', 'did:oyd'],
              "cryptographic_suites_supported": ["ES256"],
              "credential_subject_issuance": {
                "subject_proof_mode": "proof_replace",
                "notification_events_supported": ["credential_deleted_holder_signed"]
              }   
            }]
        }
        render json: retVal.to_json,
               status: 200
    end

    def sddp_sign
        issuer_host = ISSUER_HOST
        retVal = {
            "credential_issuer": issuer_host + SDDP_SIGNING_PATH,
            "credential_endpoint": issuer_host + SDDP_SIGNING_PATH + "/credentials",
            "token_endpoint": issuer_host + SDDP_SIGNING_PATH + "/token",
            "notification_endpoint": issuer_host + SDDP_SIGNING_PATH + "/notification",
            "display": [{
                "name": "DID FlexCo",
                "description": "DID Daten-Intermediär-Dienste FlexCo Credential"
            }],
            "credentials_supported": [{
              "display": [{
                "name": "Self-Declaration Credential",
                "description": "sign Self-Declaration for Data Provider",
                "text_color": "#000000",
                "background_color": "#FFFFFF"
              }],
              "id": "DaCredential",
              "types": [
                "VerifiableCredential",
                CREDENTIAL_SDDP_TYPE
              ],
              "format": "jwt_vc_json",
              "cryptographic_binding_methods_supported": ['did:jwk', 'did:oyd'],
              "cryptographic_suites_supported": ["ES256"],
              "credential_subject_issuance": {
                "subject_proof_mode": "proof_replace",
                "notification_events_supported": ["credential_deleted_holder_signed"]
              }   
            }]
        }
        render json: retVal.to_json,
               status: 200
    end

    def d2a_token
        preauth_code = params["pre-authorized_code"].to_s
        @store = Store.find_by_key(preauth_code)
        item = @store.item
        key = OpenSSL::PKey::EC.generate('prime256v1')
        algorithm = "ES256"
        header_fields = {
            alg: algorithm,
            typ: 'JWT'
        }
        payload = {
            "iat": Time.now.utc.to_i,
            "exp": 300,
            "iss": ISSUER_HOST + D2A_SIGNING_PATH,
            "preAuthorizedCode": preauth_code
        }
        access_token = JWT.encode(payload, key, algorithm, header_fields)
        nonce = SecureRandom.alphanumeric(10)
        item["nonce"] = nonce
        @item = item
        @store.key = nonce
        @store.save
        retVal = {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": 86400,
            "c_nonce": nonce,
            "c_nonce_expires_in": 86400
        }
        render json: retVal,
               status: 200
    end

    def d3a_token
        preauth_code = params["pre-authorized_code"].to_s
        @store = Store.find_by_key(preauth_code)
        item = @store.item
        key = OpenSSL::PKey::EC.generate('prime256v1')
        algorithm = "ES256"
        header_fields = {
            alg: algorithm,
            typ: 'JWT'
        }
        payload = {
            "iat": Time.now.utc.to_i,
            "exp": 300,
            "iss": ISSUER_HOST + D3A_SIGNING_PATH,
            "preAuthorizedCode": preauth_code
        }
        access_token = JWT.encode(payload, key, algorithm, header_fields)
        nonce = SecureRandom.alphanumeric(10)
        item["nonce"] = nonce
        @item = item
        @store.key = nonce
        @store.save
        retVal = {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": 86400,
            "c_nonce": nonce,
            "c_nonce_expires_in": 86400
        }
        render json: retVal,
               status: 200
    end

    def sddp_token
        preauth_code = params["pre-authorized_code"].to_s
        @store = Store.find_by_key(preauth_code)
        item = @store.item
        key = OpenSSL::PKey::EC.generate('prime256v1')
        algorithm = "ES256"
        header_fields = {
            alg: algorithm,
            typ: 'JWT'
        }
        payload = {
            "iat": Time.now.utc.to_i,
            "exp": 300,
            "iss": ISSUER_HOST + SDDP_SIGNING_PATH,
            "preAuthorizedCode": preauth_code
        }
        access_token = JWT.encode(payload, key, algorithm, header_fields)
        nonce = SecureRandom.alphanumeric(10)
        item["nonce"] = nonce
        @item = item
        @store.key = nonce
        @store.save
        retVal = {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": 86400,
            "c_nonce": nonce,
            "c_nonce_expires_in": 86400
        }
        render json: retVal,
               status: 200
    end

    def d2a_credential
        proof = params["proof"]
        jwt = proof["jwt"]
        data = JWT.decode(jwt, nil, false)
        nonce = data.first["nonce"]
        notification_id = SecureRandom.alphanumeric(32)
        @store = Store.find_by_key(nonce)
        item = @store.item
        if item.is_a?(String)
            item = JSON.parse(item) rescue {}
        end
        agreement_id = item["agreement-id"]

        @rec = Store.find(agreement_id)
        agreement_object = @rec.item
        agreement_object.delete("object-id")

        holder_did = data.first["iss"]
        issuer_did = ENV['ISSUER_DID'].strip
        sk_encoded = ENV['ISSUER_PWD'].strip
        key = Oydid.decode_private_key(sk_encoded).first

        content = {}
        content["@context"] = [
            "https://www.w3.org/2018/credentials/v1",
            "https://w3id.org/security/suites/jws-2020/v1",
            { "@vocab": SOYA_REPO_HOST + '/' + @rec.schema + '/' }
        ]
        content["credentialSubject"] = agreement_object
        content["credentialSubject"]["id"] = holder_did
        content["credentialSubject"] = stringify_numbers(content["credentialSubject"]) # !!! Sphereon Wallet can't handle numbers (v0.5.3)
        expirationDate = (Time.now + (3 * 30 * 24 * 60 * 60)).to_i # Time.now.utc + 3.months
        content["expirationDate"] = Time.at(expirationDate).strftime("%Y-%m-%dT%H:%M:%SZ")
        options = {}
        options[:issuer] = issuer_did
        options[:issuer_privateKey] = sk_encoded # issuer_pwd
        options[:holder] = holder_did
        options[:vc_type] = 'JsonWebSignature2020'
        options[:vc_location] = ISSUER_HOST + "/credentials/"
        vc, msg = Oydid.create_vc(JSON.parse(content.to_json), options)

        algorithm = 'ES256'
        header = {
            alg: algorithm,
            kid: issuer_did + '#0',
            typ: 'JWT'
        }

        encoded_header = Base64.urlsafe_encode64(header.to_json, padding: false)
        encoded_payload = Base64.urlsafe_encode64(vc.to_json, padding: false)
        data_to_sign = "#{encoded_header}.#{encoded_payload}"
        jwt_digest = OpenSSL::Digest::SHA256.new
        asn1_signature = OpenSSL::ASN1.decode(key.dsa_sign_asn1(jwt_digest.digest(data_to_sign)))
        raw_signature = asn1_signature.value.map { |i| i.value.to_s(2).rjust(32, "\x00") }.join()
        encoded_signature = Base64.urlsafe_encode64(raw_signature, padding: false)
        jwt_vc = "#{encoded_header}.#{encoded_payload}.#{encoded_signature}"

        retVal ={
          "format": "jwt_vc_json",
          "credential": jwt_vc,
          "c_nonce": nonce,
          "c_nonce_expires_in": 86400,
          "notification_id": notification_id,
          "credential_subject_issuance": {
              "subject_proof_mode": "proof_replace",
              "notification_events_supported": [
                  "credential_deleted_holder_signed"
              ]
          }
        }

        item["notification_id"] = notification_id
        if HAS_JSONB
            @store.item = item
        else
            @store.item = item.to_json
        end
        @store.key = notification_id
        @store.save

        render json: retVal,
               status: 200

    end

    def d3a_credential
        proof = params["proof"]
        jwt = proof["jwt"]
        data = JWT.decode(jwt, nil, false)
        nonce = data.first["nonce"]
        notification_id = SecureRandom.alphanumeric(32)
        @store = Store.find_by_key(nonce)
        item = @store.item
        if item.is_a?(String)
            item = JSON.parse(item) rescue {}
        end
        agreement_id = item["agreement-id"]

        @rec = Store.find(agreement_id)
        agreement_object = @rec.item
        agreement_object.delete("object-id")

        holder_did = data.first["iss"]
        issuer_did = ENV['ISSUER_DID'].strip
        sk_encoded = ENV['ISSUER_PWD'].strip
        key = Oydid.decode_private_key(sk_encoded).first

        content = {}
        content["@context"] = [
            "https://www.w3.org/2018/credentials/v1",
            "https://w3id.org/security/suites/jws-2020/v1",
            { "@vocab": SOYA_REPO_HOST + '/' + @rec.schema + '/' }
        ]
        content["credentialSubject"] = agreement_object
        content["credentialSubject"]["id"] = holder_did
        content["credentialSubject"] = stringify_numbers(content["credentialSubject"]) # !!! Sphereon Wallet can't handle numbers (v0.5.3)
        expirationDate = (Time.now + (3 * 30 * 24 * 60 * 60)).to_i # Time.now.utc + 3.months
        content["expirationDate"] = Time.at(expirationDate).strftime("%Y-%m-%dT%H:%M:%SZ")
        options = {}
        options[:issuer] = issuer_did
        options[:issuer_privateKey] = sk_encoded # issuer_pwd
        options[:holder] = holder_did
        options[:vc_type] = 'JsonWebSignature2020'
        options[:vc_location] = ISSUER_HOST + "/credentials/"
        vc, msg = Oydid.create_vc(JSON.parse(content.to_json), options)

        algorithm = 'ES256'
        header = {
            alg: algorithm,
            kid: issuer_did + '#0',
            typ: 'JWT'
        }

        encoded_header = Base64.urlsafe_encode64(header.to_json, padding: false)
        encoded_payload = Base64.urlsafe_encode64(vc.to_json, padding: false)
        data_to_sign = "#{encoded_header}.#{encoded_payload}"
        jwt_digest = OpenSSL::Digest::SHA256.new
        asn1_signature = OpenSSL::ASN1.decode(key.dsa_sign_asn1(jwt_digest.digest(data_to_sign)))
        raw_signature = asn1_signature.value.map { |i| i.value.to_s(2).rjust(32, "\x00") }.join()
        encoded_signature = Base64.urlsafe_encode64(raw_signature, padding: false)
        jwt_vc = "#{encoded_header}.#{encoded_payload}.#{encoded_signature}"

        retVal ={
          "format": "jwt_vc_json",
          "credential": jwt_vc,
          "c_nonce": nonce,
          "c_nonce_expires_in": 86400,
          "notification_id": notification_id,
          "credential_subject_issuance": {
              "subject_proof_mode": "proof_replace",
              "notification_events_supported": [
                  "credential_deleted_holder_signed"
              ]
          }
        }

        item["notification_id"] = notification_id
        if HAS_JSONB
            @store.item = item
        else
            @store.item = item.to_json
        end
        @store.key = notification_id
        @store.save

        render json: retVal,
               status: 200

    end

    def d2a_notification
        notification_id = params["notification_id"]
        @store = Store.find_by_key(notification_id)
        if !@store.nil?
            item = @store.item
            if item.is_a?(String)
                item = JSON.parse(item) rescue {}
            end
            item["credential"] = params["credential"]
            if HAS_JSONB
                @store.item = item
            else
                @store.item = item.to_json
            end
            @store.key = item["complete-code"]
            @store.save
        end
        render json: {},
               status: 200
    end

    def d3a_notification
        notification_id = params["notification_id"]
        @store = Store.find_by_key(notification_id)
        if !@store.nil?
            item = @store.item
            if item.is_a?(String)
                item = JSON.parse(item) rescue {}
            end
            item["credential"] = params["credential"]
            if HAS_JSONB
                @store.item = item
            else
                @store.item = item.to_json
            end
            @store.key = item["complete-code"]
            @store.save
        end
        render json: {},
               status: 200
    end

    private

    def stringify_numbers(obj)
      case obj
      when Hash
        obj.transform_values { |v| stringify_numbers(v) }
      when Array
        obj.map { |v| stringify_numbers(v) }
      when Integer, Float
        obj.to_s
      else
        obj
      end
    end    

end