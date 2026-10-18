# Saves a new tracker and points each repository it covers at it, in one
# transaction. A repository is checked again under a row lock before it is
# covered: the tasks that call this check first, then may wait on a person
# pasting a token, and another run can cover the repository in between.
module TrackerCoverage
  class AlreadyCovered < StandardError; end

  def self.cover!(tracker, repositories)
    ApplicationRecord.transaction do
      tracker.save!
      repositories.each do |repository|
        repository.lock!
        raise AlreadyCovered, "#{repository.name} is already covered by tracker #{repository.tracker_id}" if repository.tracker_id

        repository.update!(tracker: tracker)
      end
    end
  rescue ActiveRecord::RecordNotUnique
    raise AlreadyCovered, 'Another tracker for the same source was created at the same time'
  end
end
