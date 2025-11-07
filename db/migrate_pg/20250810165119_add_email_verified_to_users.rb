class AddEmailVerifiedToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :email_verified, :string
    add_column :users, :email_verified_at, :datetime
  end
end