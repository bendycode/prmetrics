# frozen_string_literal: true

# Repository visibility for regular users is limited to their grants, so every
# user and repository that predates grants gets one; nothing anyone sees
# changes on deploy. Admins see every repository without grants. Plain SQL
# keeps this migration independent of the model classes, so the role below
# is the integer User.roles[:regular_user] maps to.
class GrantExistingUsersRepositoryAccess < ActiveRecord::Migration[7.2]
  REGULAR_USER_ROLE = 0

  def up
    execute <<~SQL.squish
      INSERT INTO repository_grants (user_id, repository_id, created_at, updated_at)
      SELECT users.id, repositories.id, NOW(), NOW()
      FROM users CROSS JOIN repositories
      WHERE users.role = #{REGULAR_USER_ROLE}
      ON CONFLICT (user_id, repository_id) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
