class CreatePullRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :pull_requests do |t|
      t.integer :number
      t.string :title
      t.string :state
      t.boolean :draft
      t.datetime :merged_at
      t.datetime :closed_at
      t.references :repository, null: false, foreign_key: true

      t.timestamps
    end
  end
end
