class CreateAccessRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :access_requests do |t|
      t.string :name
      t.string :email
      t.text :note
      t.string :reference
      t.string :guid
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end