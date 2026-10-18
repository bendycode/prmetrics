class RenameStorySourceTimestamps < ActiveRecord::Migration[7.2]
  def change
    rename_column :stories, :gh_created_at, :source_created_at
    rename_column :stories, :gh_updated_at, :source_updated_at
  end
end
