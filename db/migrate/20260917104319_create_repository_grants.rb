class CreateRepositoryGrants < ActiveRecord::Migration[7.2]
  def change
    create_table :repository_grants do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :repository, null: false, foreign_key: true

      t.timestamps
    end

    add_index :repository_grants, %i[user_id repository_id], unique: true
  end
end
