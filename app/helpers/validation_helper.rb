module ValidationHelper
    def validate(payload, schema)
        soya_webcli_api = SOYA_WEBCLI_HOST + SOYA_WEBCLI_API_PREFIX

        acquire_url = soya_webcli_api + 'acquire/' + schema
        acquire_data = payload
        rensponse_nil = false
        begin
            acquire_response = HTTParty.post(acquire_url, 
                headers: { 'Content-Type'  => 'application/json' },
                body: acquire_data.to_json )
        rescue => ex
            response_nil = true
        end
        if response_nil
            return [false, 'error on acquire']
        end

        validation_url = soya_webcli_api + 'validate/' + schema
        validation_data = acquire_response.parsed_response
        begin
            validation_response = HTTParty.post(validation_url, 
                headers: { 'Content-Type'  => 'application/json' },
                body: validation_data.to_json )
        rescue => ex
            response_nil = true
        end
        if response_nil
            return [false, 'error on validate']
        end
        response = validation_response.parsed_response.transform_keys(&:to_s)
        if response["isValid"]
            return [true, nil]
        end
        retVal = {"errors": []}.transform_keys(&:to_sym)
        response["results"].each do |r|
            r = r.transform_keys(&:to_s)
            msg = r["message"] rescue nil
            if msg == [] || msg.to_s == ""
                val = r["value"] rescue nil
                if val.nil?
                    val = r["severity"]["value"].to_s rescue nil
                end
                if val.to_s != ""
                    retVal[:errors] << "'" + val + "' invalid"
                end
            else
                obj = {"value": r["value"], "error": r["message"].first.transform_keys(&:to_s)["value"]} rescue nil
                if !obj.nil?
                    retVal[:errors] << obj[:error].to_s
                end
            end
        end
        return [false, retVal[:errors].join(', ')]
    end
end
