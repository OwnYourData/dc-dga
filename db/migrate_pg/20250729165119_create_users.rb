class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :bpk
      t.string :given_name
      t.string :last_name
      t.string :postcode
      t.string :email
      t.string :did
      t.string :did_valid_until

      t.timestamps
    end
    add_index :users, :bpk
    add_index :users, :did
  end
end
