module EventsHelper
    def createEvent(bpk:, event_str:, event_object:)
        # !!! implement with user_id: create DID Links
        cfg = EVENT_DEFS[event_str]
        raise ArgumentError, %(unknown event_str "#{event_str}") unless cfg

        Event.create!(
            store_id:     nil,
            user:         cfg[:user] == :nil ? nil : bpk,
            timestamp:    Time.current,
            event_object: event_object,
            event_type:   cfg[:type],
            event:        cfg[:msg]
        )
    end
end