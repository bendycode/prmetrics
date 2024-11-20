class CreateGithubUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :github_users do |t|
      t.string :username, null: false
      t.string :name
      t.string :avatar_url
      t.string :github_id, null: false
      t.timestamps
      t.index :github_id, unique: true
      t.index :username
    end

    add_reference :pull_requests, :author, null: true, foreign_key: { to_table: :github_users }
  end
end
