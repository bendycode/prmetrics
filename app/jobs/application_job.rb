class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # A job whose record was deleted after it was queued has nothing left to do.
  # ActiveJob raises the same error for any failure while loading the record,
  # so anything else, such as a lost database connection, still retries.
  discard_on ActiveJob::DeserializationError do |_job, error|
    raise error unless error.cause.is_a?(ActiveRecord::RecordNotFound)
  end
end
