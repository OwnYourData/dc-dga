class AddAuthTimeToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :ida_auth_time, :integer
  end
end