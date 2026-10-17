class CreateStories < ActiveRecord::Migration[7.2]
  def change
    create_table :stories do |t|
      t.references :tracker, null: false, foreign_key: true, index: false
      t.string :external_id, null: false
      t.string :key, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.string :state, null: false
      t.string :state_reason
      t.datetime :gh_created_at, null: false
      t.datetime :gh_updated_at, null: false
      t.datetime :listed_at
      t.boolean :gone, null: false, default: false
      t.datetime :committed_at
      t.integer :committed_source
      t.datetime :started_at
      t.integer :started_source
      t.datetime :done_at
      t.timestamps
      t.index %i[tracker_id external_id], unique: true
    end
  end
end
