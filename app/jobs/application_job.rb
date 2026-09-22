class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # A job whose record was deleted after it was queued has nothing left to do
  discard_on ActiveJob::DeserializationError
end
