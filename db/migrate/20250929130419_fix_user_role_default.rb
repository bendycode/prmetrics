class FixUserRoleDefault < ActiveRecord::Migration[7.1]
  def change
    # Match model default now that existing admins have been converted
    change_column_default :users, :role, from: 1, to: 0
  end
end
