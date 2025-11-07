Rails.application.config.to_prepare do
  if ActiveRecord::Base.connection.adapter_name != 'PostgreSQL'
    Store.attribute :item, :json, default: {}
    Store.attribute :meta, :json, default: {}
    Event.attribute :event_object, :json, default: {}
  end
end