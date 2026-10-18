class CreateTrackers < ActiveRecord::Migration[7.2]
  def change
    create_table :trackers do |t|
      t.integer :kind, null: false
      t.references :source_repository, foreign_key: { to_table: :repositories }, index: { unique: true }
      t.jsonb :config, null: false, default: {}
      t.timestamps
    end
  end
end
