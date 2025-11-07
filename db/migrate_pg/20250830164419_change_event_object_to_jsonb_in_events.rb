class ChangeEventObjectToJsonbInEvents < ActiveRecord::Migration[5.2]
  def change
    remove_column :events, :event_object
    add_column :events, :event_object, :jsonb, default: {}, null: false
  end
end