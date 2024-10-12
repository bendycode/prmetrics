class CreatePullRequestUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :pull_request_users do |t|
      t.string :role
      t.references :pull_request, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
