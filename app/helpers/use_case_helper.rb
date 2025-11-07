module UseCaseHelper

    def expiry_from_duration(str)
        return nil if str.blank?
        m = str.to_s.strip.downcase.match(/\A(\d+)\s*([[:alpha:]\.\-]+)\z/)
        return nil unless m

        number = m[1].to_i
        unit_key = UNIT_ALIASES[m[2].tr('.-', '')] # "." und "-" tolerieren
        return nil unless unit_key

        # Rails-Zeitzone beachten:
        number.public_send(unit_key).from_now.to_i
    end
    
    def current_usecase(store_id: nil, short: nil, schema: nil)
        soya_url = false
        if short.nil?
            if store_id.nil?
                short = nil
                USE_CASES.each do |key, cfg|
                    if cfg[:D2A_schema] == schema || 
                        cfg[:D3A_schema] == schema ||
                        cfg[:contract_schema] == schema ||
                        cfg[:consent_schema] == schema
                            short = key
                            break
                    end                    
                end
            else
                @store = Store.find(store_id)
                case @store.schema
                when 'D2Aeeg', 'D3Aeeg', 'EEGconsent', 'EegConsentForm'
                    short = 'eeg_altruism'
                when 'D2AapiSharing', 'D3AapiSharing', 'ApiSharingConsent', 'ApiSharingConsentForm'
                    short = 'api_sharing'
                end
                schema = @store.schema
            end
            if ['EEGconsent', 'ApiSharingConsent'].include?(schema)
                soya_url = true
            end
        end
        if short.to_s == ''
            nil
        else
            retVal = USE_CASES[short]
            retVal[:soya_url] = soya_url
            retVal
        end
    end

    def process_D2Aeeg_signature(store_id, rec_id=nil)
        if rec_id.nil?
            @store = Store.find(store_id)
            item = @store.item
            if item.is_a?(String)
                item = JSON.parse(item) rescue {}
            end
            @rec = Store.find(item["agreement-id"])
        else
            @rec = Store.find(rec_id)
        end
        item_data = @rec.item
        schema = @rec.schema
        bpk = @rec.user
        @user = User.find_by_bpk(bpk)
        user_did = @user.did

        # Overview of steps for Use Case
        # - on Pod level
        #   + create Organsiation (incl. admin user)
        #     . log new org
        #     . log new user
        #   + create 2 collections: parent record & detail data
        #   + write data for parent record
        #     . log parent collection
        #   + create VC documenting D2A for collection
        #     . log VC creation
        #   + store VC with signed D2A in collection
        #     . log for detail collection
        # - on Orchestrator level
        #   + create Contract entry with D2A record
        #     . log new contract entry
        #   + create Data Catalog entry
        #     . log new data catalog entry

        # == Contract entry ====
        credential_encoded = @store.item['credential']
        credential = JWT.decode credential_encoded, nil, false rescue nil
        sig_ts = credential.first["nbf"]
        contract_payload = {
            "contract_type": "Data Sharing Agreement",
            "description": item_data.dup["description"].sub(/^.*\(([^)]+)\).*$/, 'EEG \1'),
            "did": current_user[:did],
            "bpk": bpk,
            "vc_jwt": credential_encoded.to_s,
            "signature_timestamp_utc": sig_ts,
            "signature_timestamp": Time.at(credential.first["nbf"]).iso8601,
            "ida_signature": current_user[:signature],
            "payload": item_data.dup
        }
        meta_data = {"repo": "contracts", "user": bpk}
        dri = Oydid.hash(Oydid.canonical({"data": contract_payload, "meta": meta_data}.to_json))
        @store = Store.new
        @store.item = contract_payload
        @store.schema = 'D2Aeeg'
        @store.meta = meta_data
        @store.repo = 'contracts'
        @store.user = bpk
        @store.dri = dri
        if !@store.save
            return [false, @store.errors.full_messages]
        end
        contract_id = @store.id
        createEvent(bpk: bpk, 
                    event_str: 'contract_d2a', 
                    event_object: @store.item )

        # == Data Catalog entry ====
        data_catalog_payload = item_data.dup
        data_catalog_payload["description"] = data_catalog_payload["description"].sub(/^.*\(([^)]+)\).*$/, 'EEG \1')
        meta_data = {"repo": "data", "tag": "mini", "contract-id": contract_id, "user": bpk}
        dri = Oydid.hash(Oydid.canonical({"data": data_catalog_payload, "meta": meta_data}.to_json))
        @store = Store.new
        @store.item = data_catalog_payload
        @store.schema = 'D2Aeeg'
        @store.meta = meta_data
        @store.repo = 'data'
        @store.dri = dri
        @store.user = bpk
        if !@store.save
            return [false, @store.errors.full_messages]
        end
        createEvent(bpk: bpk, 
                    event_str: 'data_init', 
                    event_object: @store.item )

        return [true, nil]
    end

    def process_D2AapiSharing_signature(store_id, rec_id=nil)
        if rec_id.nil?
            @store = Store.find(store_id)
            item = @store.item
            if item.is_a?(String)
                item = JSON.parse(item) rescue {}
            end
            @rec = Store.find(item["agreement-id"])
        else
            @rec = Store.find(rec_id)
        end
        item_data = @rec.item
        schema = @rec.schema
        bpk = @rec.user
        @user = User.find_by_bpk(bpk)
        user_did = @user.did
        cuc = current_usecase(schema:)

        # == Pod-level: create org & admin user
        pod_token = getToken(cuc[:pod_url] + '/oauth/token', cuc[:pod_key], cuc[:pod_secret], 'admin')
        pod_url_org = cuc[:pod_url].to_s + '/organization/'
        org_name = item_data["subject"]["providerTitle"] +
            ' (' + item_data["subject"]["providerType"] +
            ' #' + item_data["subject"]["providerRegisteredNumber"] + ')' rescue ""
        org_data = {
            "name": org_name
        }
        retVal = HTTParty.post(pod_url_org,
            headers: { 'Content-Type'  => 'application/json',
                       'Authorization' => 'Bearer ' + pod_token.to_s },
            body: org_data.to_json )
        user_id = retVal["admin-user-id"]
        org_id = retVal["organization-id"]

        # get User Credentials
        pod_url_wallet = cuc[:pod_url].to_s + '/user/' + user_id.to_s + '/wallet'
        retVal = HTTParty.get(pod_url_wallet,
            headers: { 'Authorization' => 'Bearer ' + pod_token.to_s })
        user_key = retVal["oauth"]["client-id"]
        user_secret = retVal["oauth"]["client-secret"]

        # == Pod-level: create collection with API information
        pod_url_collection = cuc[:pod_url].to_s + '/collection/'
        pod_token = getToken(cuc[:pod_url] + '/oauth/token', user_key, user_secret)
        collection_name = "API Credentials from " + org_name
        credentialSubject = @rec.item
        credentialSubject['description'] = credentialSubject['description'].sub(/^Draft - /, '')
        cs_id = credentialSubject.delete("object-id")
        collection_data = {
            "name": collection_name,
            "source_url": @rec.item["source"]["a_source"],
            "token_endpoint": @rec.item["source"]["b_tokenEp"],
            "api_key": @rec.item["source"]["c_apiKeyStr"],
            "client_id": @rec.item["source"]["d_client_Ident"],
            "client_secret": @rec.item["source"]["e_client_Secret"],
            "description": @rec.item["source"]["f_description_long"],
            "meta": {
                "d2a_jwt_vc": @store.item["credential"],
                "d2a_credentialSubject": credentialSubject,
                "credentialSubject_id": cs_id
            }
        }
        retVal = HTTParty.post(pod_url_collection,
            headers: { 'Content-Type'  => 'application/json',
                       'Authorization' => 'Bearer ' + pod_token.to_s },
            body: collection_data.to_json )
        collection_id = retVal["collection-id"]

        # create DID for collection
        options = {
            :location => cuc[:pod_url].to_s,
            :key_type => 'ed25519',
            :doc_pwd => ENV['DOC_PWD'],
            :rev_pwd => ENV['REV_PWD']
        }
        content = {
            service: [
                {
                    id: "#collection", 
                    type:"StorageService", 
                    serviceEndpoint: pod_url_collection + collection_id.to_s
                }
            ]
        }

        collection_did_info, msg = Oydid.create(content, options)
        collection_did = collection_did_info['did']
        collection_data[:meta]['collection-id'] = collection_id
        collection_data[:meta]['did'] = collection_did
        retVal = HTTParty.put(pod_url_collection + collection_id.to_s,
            headers: { 'Content-Type'  => 'application/json',
                       'Authorization' => 'Bearer ' + pod_token.to_s },
            body: collection_data.to_json )

        # == Contract entry ====
        credential_encoded = @store.item['credential']
        credential = JWT.decode credential_encoded, nil, false rescue nil
        sig_ts = credential.first["nbf"]
        contract_payload = {
            "contract_type": "Data Sharing Agreement",
            "description": item_data.dup["description"].sub(/^Draft - Data Sharing Agreement - /, '').sub(/^Data Sharing Agreement - /, ''),
            "did": current_user[:did],
            "bpk": bpk,
            "vc_jwt": credential_encoded.to_s,
            "signature_timestamp_utc": sig_ts,
            "signature_timestamp": Time.at(credential.first["nbf"]).iso8601,
            "ida_signature": current_user[:signature],
            "payload": item_data.dup,
            "collection": {
                "pod-url": cuc[:pod_url].to_s,
                "id": collection_id.to_s,
                "did": collection_did,
                "client-id": user_key,
                "client-secret": user_secret,
                "user-id": user_id,
                "organization-id": org_id }
        }
        meta_data = {"repo": "contracts", "user": bpk}
        dri = Oydid.hash(Oydid.canonical({"data": contract_payload, "meta": meta_data}.to_json))
        @store = Store.new
        @store.item = contract_payload
        @store.schema = 'D2AapiSharing'
        @store.meta = meta_data
        @store.repo = 'contracts'
        @store.user = bpk
        @store.dri = dri
        if !@store.save
            return [false, @store.errors.full_messages]
        end
        contract_id = @store.id
        createEvent(bpk: bpk, 
                    event_str: 'contract_d2a', 
                    event_object: @store.item )

        # == Data Catalog entry ====
        data_catalog_payload = item_data.dup
        data_catalog_payload["description"] = data_catalog_payload["description"].sub(/^Draft - Data Sharing Agreement - /, '').sub(/^Data Sharing Agreement - /, '')
        meta_data = {"repo": "data", "tag": "mini", "contract-id": contract_id, "user": bpk}
        dri = Oydid.hash(Oydid.canonical({"data": data_catalog_payload, "meta": meta_data}.to_json))
        @store = Store.new
        @store.item = data_catalog_payload
        @store.schema = 'D2AapiSharing'
        @store.meta = meta_data
        @store.repo = 'data'
        @store.dri = dri
        @store.user = bpk
        if !@store.save
            return [false, @store.errors.full_messages]
        end
        createEvent(bpk: bpk, 
                    event_str: 'data_init', 
                    event_object: @store.item )

        return [true, nil]
    end    

    def process_D3Aeeg_signature(store_id, rec_id=nil)
        if rec_id.nil?
            @store = Store.find(store_id)
            item = @store.item
            if item.is_a?(String)
                item = JSON.parse(item) rescue {}
            end
            @rec = Store.find(item["agreement-id"])
        else
            @rec = Store.find(rec_id)
        end
        item_data = @rec.item
        schema = @rec.schema
        bpk = @rec.user
        @user = User.find_by_bpk(bpk)
        user_did = @user.did
        @d2a_rec = Store.find(item_data["data_id"])
        @d2a_contract = Store.find(@d2a_rec.meta["contract-id"])
        cuc = current_usecase(schema: schema)

        # Overview of steps for Use Case
        #   + create Contract entry with D3A record
        #     . log new contract entry
        #   + create Contract entry with Consent record compiled from D2A & D3A incl. credentials
        #     . log new consent record in my contracts

        # == Contract entry ====
        credential_encoded = @store.item['credential']
        credential = JWT.decode credential_encoded, nil, false rescue nil
        sig_ts = credential.first["nbf"]
        d3a_payload = {
            "contract_type": "Data Disclosure Agreement",
            "description": item_data.dup["description"].sub(/^.*\(([^)]+)\).*$/, 'EEG \1'),
            "did": current_user[:did],
            "bpk": bpk,
            "vc_jwt": credential_encoded.to_s,
            "signature_timestamp_utc": sig_ts,
            "signature_timestamp": Time.at(credential.first["nbf"]).iso8601,
            "ida_signature": current_user[:signature],
            "payload": item_data.dup
        }
        meta_data = {"repo": "contracts", "user": bpk}
        dri = Oydid.hash(Oydid.canonical({"data": d3a_payload, "meta": meta_data}.to_json))
        @store = Store.new
        @store.item = d3a_payload
        @store.schema = 'D3Aeeg'
        @store.meta = meta_data
        @store.repo = 'contracts'
        @store.user = bpk
        @store.dri = dri
        if !@store.save
            return [false, @store.errors.full_messages]
        end
        contract_id = @store.id
        createEvent(bpk: bpk, 
                    event_str: 'contract_d3a', 
                    event_object: @store.item )

        # == Consent entry ====
        # build DID for Consent Record
        options = {}
        options[:key_type] = 'ed25519'
        contract_did_info, msg = Oydid.create(nil, options)
        contract_did = contract_did_info["did"]

        # build input for creating consent record
        consent_input = {
            input: {
                schema_version: SOYA_REPO_HOST + '/' + cuc[:consent_schema],
                record_id: contract_did,
                intermediary_did: ENV['DID_FLEXCO_DID'],
                intermediary_bpk: ENV['DID_FLEXCO_BPK']
            },
            d2a: @d2a_contract.item,
            d3a: d3a_payload
        }

        # perform transformation
        soya_webcli_api = SOYA_WEBCLI_HOST + SOYA_WEBCLI_API_PREFIX
        transformation_url = soya_webcli_api + 'transform/' + cuc[:consent_tranform].to_s
        transformation_data = consent_input
        response_nil = false
        begin
            transformation_response = HTTParty.post(transformation_url, 
                headers: { 'Content-Type'  => 'application/json' },
                body: transformation_data.to_json )
        rescue => ex
            response_nil = true
        end
        if response_nil
            return [false, 'cannot create consent record from transformation']
        end

        consent_payload = {
            "contract_type": "Consent Record",
            "description": @d2a_contract.item['description'].to_s + ' <-> ' + item_data.dup["description"].sub(/^.*\(([^)]+)\).*$/, 'EEG \1'),
            "payload": transformation_response.parsed_response
        }
        meta_data = {"repo": "contracts", "user": bpk}
        dri = Oydid.hash(Oydid.canonical({"data": consent_payload, "meta": meta_data}.to_json))
        @store = Store.new
        @store.item = consent_payload
        @store.schema = cuc[:consent_tranform]
        @store.meta = meta_data
        @store.repo = 'contracts'
        @store.user = bpk
        @store.dri = dri
        if !@store.save
            return [false, @store.errors.full_messages]
        end
        createEvent(bpk: bpk, 
                    event_str: 'consent_record', 
                    event_object: @store.item )

        return [true, nil]
    end

    def process_D3AapiSharing_signature(store_id, rec_id=nil)
        if rec_id.nil?
            @store = Store.find(store_id)
            item = @store.item
            if item.is_a?(String)
                item = JSON.parse(item) rescue {}
            end
            @rec = Store.find(item["agreement-id"])
        else
            @rec = Store.find(rec_id)
        end
        item_data = @rec.item
        if item_data['processingType'] == 'transform'
            item_data['transformation_schema'] = 'EegSenML'
        end
        schema = @rec.schema
        bpk = @rec.user
        @user = User.find_by_bpk(bpk)
        user_did = @user.did
        @d2a_rec = Store.find(item_data["data_id"])
        @d2a_contract = Store.find(@d2a_rec.meta["contract-id"])
        cuc = current_usecase(schema: schema)

        # == Contract entry ====
        credential_encoded = @store.item['credential']
        credential = JWT.decode credential_encoded, nil, false rescue nil
        sig_ts = credential.first["nbf"]
        d3a_payload = {
            "contract_type": "Data Disclosure Agreement",
            "description": item_data.dup["description"].sub(/^Draft - Data Sharing Agreement - /, ''),
            "did": current_user[:did],
            "bpk": bpk,
            "vc_jwt": credential_encoded.to_s,
            "signature_timestamp_utc": sig_ts,
            "signature_timestamp": Time.at(credential.first["nbf"]).iso8601,
            "ida_signature": current_user[:signature],
            "payload": item_data.dup
        }
        meta_data = {"repo": "contracts", "user": bpk}
        dri = Oydid.hash(Oydid.canonical({"data": d3a_payload, "meta": meta_data}.to_json))
        @store = Store.new
        @store.item = d3a_payload
        @store.schema = 'D3AapiSharing'
        @store.meta = meta_data
        @store.repo = 'contracts'
        @store.user = bpk
        @store.dri = dri
        if !@store.save
            return [false, @store.errors.full_messages]
        end
        contract_id = @store.id
        createEvent(bpk: bpk, 
                    event_str: 'contract_d3a', 
                    event_object: @store.item )

        # == Update Sharing pod with new data consumer =====
        # collect data
        pod_url = @d2a_contract.item["collection"]["pod-url"]
        pod_url_token = pod_url + '/oauth/token'
        pod_url_collection = pod_url + '/collection/' + @d2a_contract.item["collection"]["id"].to_s
        admin_user_id = @d2a_contract.item["collection"]["user-id"]
        org_id = @d2a_contract.item["collection"]["organization-id"]
        admin_key = @d2a_contract.item["collection"]["client-id"]
        admin_secret = @d2a_contract.item["collection"]["client-secret"]
        pod_admin_token = getToken(pod_url_token, admin_key, admin_secret, 'write')

        # create user (add to organisation)
        user_name = @rec.item["subject"]["receiverContact"]["name"] rescue SecureRandom.alphanumeric(10)
        user_obj = {
            name: user_name,
            "organization-id": org_id,
            scope: "read"
        }
        pod_create_user_url = pod_url + '/user'
        retVal = HTTParty.post(pod_create_user_url,
            headers: { 'Content-Type'  => 'application/json',
                       'Authorization' => 'Bearer ' + pod_admin_token.to_s },
            body: user_obj.to_json )
        user_id = retVal["user-id"]

        # get User Credentials
        pod_url_wallet = pod_url + '/user/' + user_id.to_s + '/wallet'
        retVal = HTTParty.get(pod_url_wallet,
            headers: { 'Authorization' => 'Bearer ' + pod_admin_token.to_s })
        user_key = retVal["oauth"]["client-id"]
        user_secret = retVal["oauth"]["client-secret"]

        # update collection's meta data with D3A to document access
        retVal = HTTParty.get(pod_url_collection,
            headers: { 'Authorization' => 'Bearer ' + pod_admin_token.to_s } )
        collection_data = retVal.parsed_response
        retVal = HTTParty.get(pod_url_collection + '/meta',
            headers: { 'Authorization' => 'Bearer ' + pod_admin_token.to_s } )
        collection_meta = retVal.parsed_response
        if collection_meta['d3a'].nil?
            collection_meta['d3a'] = [d3a_payload]
        else
            collection_meta['d3a'] << d3a_payload
        end
        collection_data['meta'] = collection_meta
        retVal = HTTParty.put(pod_url_collection,
            headers: { 'Content-Type'  => 'application/json',
                       'Authorization' => 'Bearer ' + pod_admin_token.to_s },
            body: collection_data.to_json )

        # == Consent entry ====
        # build DID for Consent Record
        options = {}
        options[:key_type] = 'ed25519'
        contract_did_info, msg = Oydid.create(nil, options)
        contract_did = contract_did_info["did"]

        # build input for creating consent record
        processingType = d3a_payload[:payload]["processingType"]
        requestUrl = ''
        case processingType
        when 'token'
            requestUrl = pod_url + '/share/oauth/token'
        when 'data'
            requestUrl = pod_url + '/share/data'
        when 'transform'
            requestUrl = pod_url + '/share/data/senml'
        end
        consent_input = {
            input: {
                schema_version: SOYA_REPO_HOST + '/' + cuc[:consent_schema],
                record_id: contract_did,
                intermediary_did: ENV['DID_FLEXCO_DID'],
                intermediary_bpk: ENV['DID_FLEXCO_BPK'],
                apiAccess: {
                    method: processingType,
                    token_url: pod_url_token,
                    request_url: requestUrl,
                    client_id: user_key,
                    client_secret: user_secret,
                    description: @d2a_contract.item['payload']['source']['f_description_long']
                }
            },
            d2a: @d2a_contract.item,
            d3a: d3a_payload
        }

        # perform transformation
        soya_webcli_api = SOYA_WEBCLI_HOST + SOYA_WEBCLI_API_PREFIX
        transformation_url = soya_webcli_api + 'transform/' + cuc[:consent_tranform].to_s
        transformation_data = consent_input
        response_nil = false
        begin
            transformation_response = HTTParty.post(transformation_url, 
                headers: { 'Content-Type'  => 'application/json' },
                body: transformation_data.to_json )
        rescue => ex
            response_nil = true
        end
        if response_nil
            return [false, 'cannot create consent record from transformation']
        end
        consent_payload = {
            "contract_type": "Consent Record",
            "description": @d2a_contract.item['description'].to_s + ' <-> ' + item_data.dup["description"].sub(/^.*\(([^)]+)\).*$/, 'EEG \1'),
            "payload": transformation_response.parsed_response
        }
        meta_data = {"repo": "contracts", "user": bpk}
        dri = Oydid.hash(Oydid.canonical({"data": consent_payload, "meta": meta_data}.to_json))
        @store = Store.new
        @store.item = consent_payload
        @store.schema = cuc[:consent_tranform]
        @store.meta = meta_data
        @store.repo = 'contracts'
        @store.user = bpk
        @store.dri = dri
        if !@store.save
            return [false, @store.errors.full_messages]
        end
        createEvent(bpk: bpk, 
                    event_str: 'consent_record', 
                    event_object: @store.item )

        return [true, nil]
    end
end

