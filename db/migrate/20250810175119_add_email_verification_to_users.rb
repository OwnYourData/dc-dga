class AddEmailVerificationToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :email_verification_token, :string
    add_column :users, :email_verification_expires_at, :datetime
  end
end