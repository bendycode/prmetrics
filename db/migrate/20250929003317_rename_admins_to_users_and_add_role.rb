class RenameAdminsToUsersAndAddRole < ActiveRecord::Migration[7.1]
  def change
    rename_table :admins, :users
    add_column :users, :role, :integer, default: 1, null: false
    add_index :users, :role
  end
end
