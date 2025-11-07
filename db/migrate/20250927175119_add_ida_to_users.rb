class AddIdaToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :qaa_eidas_level, :string
    add_column :users, :signature, :text
  end
end