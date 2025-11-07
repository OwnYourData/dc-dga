class AddRepoToStores < ActiveRecord::Migration[7.1]
  def change
    add_column :stores, :repo, :string
    add_column :stores, :user, :string
    add_index :stores, :repo
    add_index :stores, :user
    add_index :stores, [:user, :repo]
  end
end