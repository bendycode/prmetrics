class FixPolymorphicInvitedByType < ActiveRecord::Migration[7.1]
  def up
    # Fix polymorphic invited_by_type references after Admin -> User migration
    # Update all 'Admin' type references to 'User' to fix the "uninitialized constant Admin" error
    User.where(invited_by_type: 'Admin').update_all(invited_by_type: 'User')
  end

  def down
    # Revert back to 'Admin' references (though this would break the app since Admin class no longer exists)
    User.where(invited_by_type: 'User').update_all(invited_by_type: 'Admin')
  end
end