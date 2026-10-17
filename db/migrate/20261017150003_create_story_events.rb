class CreateStoryEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :story_events do |t|
      t.references :story, null: false, foreign_key: true, index: false
      t.string :external_id, null: false
      t.integer :kind, null: false
      t.datetime :occurred_at, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps
      t.index %i[story_id external_id], unique: true
    end
  end
end
