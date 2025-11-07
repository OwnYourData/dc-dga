class CreateEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :events do |t|
      t.integer :store_id
      t.string :user
      t.datetime :timestamp
      t.integer :event_type
      t.text :event_object
      t.string :event

      t.timestamps
    end
    add_index :events, :user
  end
end
