class IndexTrackersOnShortcutWorkflow < ActiveRecord::Migration[7.2]
  # One Shortcut tracker per workflow, held by the database as well as the
  # model so two runs creating trackers at once cannot both succeed. Kind 1 is
  # Tracker's shortcut kind.
  def change
    add_index :trackers, "(config->>'workflow_id')", unique: true, where: 'kind = 1',
                                                      name: 'index_trackers_on_shortcut_workflow'
  end
end
