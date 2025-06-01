class CreateContributorsAndConsolidateUserModels < ActiveRecord::Migration[7.1]
  def up
    # Create contributors table with all necessary fields
    create_table :contributors do |t|
      t.string :username, null: false
      t.string :name
      t.string :email
      t.string :avatar_url
      t.string :github_id, null: false
      t.timestamps null: false
    end
    
    # Add indexes
    add_index :contributors, :github_id, unique: true
    add_index :contributors, :username
    
    # Migrate data from both tables
    migrate_data_to_contributors
    
    # Update foreign keys to point to contributors
    update_foreign_keys
    
    # Drop old tables
    drop_table :github_users
    drop_table :users
  end
  
  def down
    # Recreate original tables
    create_table :users do |t|
      t.string :username
      t.string :name
      t.string :email
      t.timestamps null: false
    end
    add_index :users, :username, name: "idx_users_username"
    
    create_table :github_users do |t|
      t.string :username, null: false
      t.string :name
      t.string :avatar_url
      t.string :github_id, null: false
      t.timestamps null: false
    end
    add_index :github_users, :github_id, unique: true
    add_index :github_users, :username
    
    # Restore foreign keys
    restore_foreign_keys
    
    # Migrate data back
    migrate_data_from_contributors
    
    # Drop contributors table
    drop_table :contributors
  end
  
  private
  
  def migrate_data_to_contributors
    # First, insert all github_users (they have github_id)
    execute <<-SQL
      INSERT INTO contributors (username, name, avatar_url, github_id, created_at, updated_at)
      SELECT username, name, avatar_url, github_id, created_at, updated_at
      FROM github_users
    SQL
    
    # Then, insert users that don't already exist as contributors (match by username)
    execute <<-SQL
      INSERT INTO contributors (username, name, email, github_id, created_at, updated_at)
      SELECT 
        users.username,
        users.name,
        users.email,
        'user_' || users.id, -- Create a unique github_id for existing users
        users.created_at,
        users.updated_at
      FROM users
      WHERE users.username NOT IN (SELECT username FROM contributors)
        AND users.username IS NOT NULL
    SQL
    
    # Update email for contributors where we have it from users table
    execute <<-SQL
      UPDATE contributors
      SET email = users.email
      FROM users
      WHERE contributors.username = users.username
        AND contributors.email IS NULL
        AND users.email IS NOT NULL
    SQL
  end
  
  def update_foreign_keys
    # Update pull_requests.author_id to reference contributors
    add_column :pull_requests, :author_id_new, :bigint
    execute <<-SQL
      UPDATE pull_requests
      SET author_id_new = contributors.id
      FROM contributors, github_users
      WHERE github_users.id = pull_requests.author_id
        AND contributors.github_id = github_users.github_id
    SQL
    remove_column :pull_requests, :author_id
    rename_column :pull_requests, :author_id_new, :author_id
    add_foreign_key :pull_requests, :contributors, column: :author_id
    add_index :pull_requests, :author_id
    
    # Update reviews.author_id to reference contributors
    add_column :reviews, :author_id_new, :bigint
    execute <<-SQL
      UPDATE reviews
      SET author_id_new = contributors.id
      FROM contributors, users
      WHERE users.id = reviews.author_id
        AND contributors.username = users.username
    SQL
    remove_column :reviews, :author_id
    rename_column :reviews, :author_id_new, :author_id
    add_foreign_key :reviews, :contributors, column: :author_id
    add_index :reviews, :author_id
    
    # Update pull_request_users.user_id to reference contributors
    add_column :pull_request_users, :user_id_new, :bigint
    execute <<-SQL
      UPDATE pull_request_users
      SET user_id_new = contributors.id
      FROM contributors, users
      WHERE users.id = pull_request_users.user_id
        AND contributors.username = users.username
    SQL
    remove_column :pull_request_users, :user_id
    rename_column :pull_request_users, :user_id_new, :user_id
    add_foreign_key :pull_request_users, :contributors, column: :user_id
    add_index :pull_request_users, :user_id
  end
  
  def restore_foreign_keys
    # Restore pull_requests.author_id to reference github_users
    add_column :pull_requests, :author_id_new, :bigint
    execute <<-SQL
      UPDATE pull_requests
      SET author_id_new = github_users.id
      FROM github_users, contributors
      WHERE contributors.id = pull_requests.author_id
        AND github_users.github_id = contributors.github_id
    SQL
    remove_column :pull_requests, :author_id
    rename_column :pull_requests, :author_id_new, :author_id
    add_foreign_key :pull_requests, :github_users, column: :author_id
    add_index :pull_requests, :author_id
    
    # Restore reviews.author_id to reference users
    add_column :reviews, :author_id_new, :bigint
    execute <<-SQL
      UPDATE reviews
      SET author_id_new = users.id
      FROM users, contributors
      WHERE contributors.id = reviews.author_id
        AND users.username = contributors.username
    SQL
    remove_column :reviews, :author_id
    rename_column :reviews, :author_id_new, :author_id
    add_foreign_key :reviews, :users, column: :author_id
    add_index :reviews, :author_id
    
    # Restore pull_request_users.user_id to reference users
    add_column :pull_request_users, :user_id_new, :bigint
    execute <<-SQL
      UPDATE pull_request_users
      SET user_id_new = users.id
      FROM users, contributors
      WHERE contributors.id = pull_request_users.user_id
        AND users.username = contributors.username
    SQL
    remove_column :pull_request_users, :user_id
    rename_column :pull_request_users, :user_id_new, :user_id
    add_foreign_key :pull_request_users, :users, column: :user_id
    add_index :pull_request_users, :user_id
  end
  
  def migrate_data_from_contributors
    # Restore github_users from contributors with original github_id
    execute <<-SQL
      INSERT INTO github_users (username, name, avatar_url, github_id, created_at, updated_at)
      SELECT username, name, avatar_url, github_id, created_at, updated_at
      FROM contributors
      WHERE github_id NOT LIKE 'user_%'
    SQL
    
    # Restore users from contributors
    execute <<-SQL
      INSERT INTO users (username, name, email, created_at, updated_at)
      SELECT DISTINCT username, name, email, created_at, updated_at
      FROM contributors
      WHERE github_id LIKE 'user_%'
         OR username IN (
           SELECT DISTINCT users.username 
           FROM pull_request_users
           JOIN users ON users.id = pull_request_users.user_id
         )
         OR username IN (
           SELECT DISTINCT users.username
           FROM reviews
           JOIN users ON users.id = reviews.author_id
         )
    SQL
  end
end