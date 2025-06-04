class SyncRepositoryBatchJob < ApplicationJob
  queue_as :default
  
  BATCH_SIZE = 100
  
  def perform(repository_name, page: 1, fetch_all: false)
    repository = Repository.find_by!(name: repository_name)
    
    # Mark as in progress on first page
    if page == 1
      repository.update!(
        sync_status: 'in_progress',
        sync_started_at: Time.current,
        last_sync_error: nil
      )
    end
    
    service = GithubService.new(ENV['GITHUB_ACCESS_TOKEN'])
    
    # Fetch one page of PRs
    pull_requests = fetch_pull_requests_page(service, repository, page)
    
    if pull_requests.empty?
      # We've reached the end
      finalize_sync(repository)
    else
      # Process this batch
      process_pull_requests(service, repository, pull_requests)
      
      # Update progress
      update_progress(repository, page, pull_requests.size)
      
      # Check if we should continue
      if should_continue_fetching?(repository, pull_requests, fetch_all)
        # Queue next page
        SyncRepositoryBatchJob.perform_later(repository_name, page: page + 1, fetch_all: fetch_all)
      else
        finalize_sync(repository)
      end
    end
  rescue => e
    handle_sync_error(repository, e)
    raise # Re-raise to trigger Sidekiq retry
  end
  
  private
  
  def fetch_pull_requests_page(service, repository, page)
    # We need to directly use Octokit since GithubService doesn't expose the client
    client = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
    client.pull_requests(
      repository.name,
      state: 'all',
      per_page: BATCH_SIZE,
      page: page,
      sort: 'updated',
      direction: 'desc'
    )
  end
  
  def process_pull_requests(service, repository, pull_requests)
    # For now, we'll use the existing GithubService logic by calling the full method
    # This is inefficient but works until we refactor GithubService
    pull_requests.each do |pr_data|
      # Recreate the processing logic from GithubService
      process_single_pull_request(repository, pr_data)
    end
  end
  
  def process_single_pull_request(repository, pr_data)
    # Handle both Octokit objects and hashes
    pr_number = pr_data.respond_to?(:number) ? pr_data.number : pr_data[:number]
    
    pull_request = repository.pull_requests.find_or_initialize_by(number: pr_number)
    
    # Create/update author first if present
    user_data = pr_data.respond_to?(:user) ? pr_data.user : pr_data[:user]
    github_user = nil
    if user_data
      github_id = user_data.respond_to?(:id) ? user_data.id : user_data[:id]
      github_user = Contributor.find_or_create_by(github_id: github_id.to_s) do |c|
        c.username = user_data.respond_to?(:login) ? user_data.login : user_data[:login]
        c.name = user_data.respond_to?(:name) ? user_data.name : user_data[:name]
        c.avatar_url = user_data.respond_to?(:avatar_url) ? user_data.avatar_url : user_data[:avatar_url]
      end
    end
    
    pull_request.assign_attributes(
      title: pr_data.respond_to?(:title) ? pr_data.title : pr_data[:title],
      state: pr_data.respond_to?(:state) ? pr_data.state : pr_data[:state],
      gh_created_at: pr_data.respond_to?(:created_at) ? pr_data.created_at : pr_data[:created_at],
      gh_updated_at: pr_data.respond_to?(:updated_at) ? pr_data.updated_at : pr_data[:updated_at],
      gh_closed_at: pr_data.respond_to?(:closed_at) ? pr_data.closed_at : pr_data[:closed_at],
      gh_merged_at: pr_data.respond_to?(:merged_at) ? pr_data.merged_at : pr_data[:merged_at],
      ready_for_review_at: (pr_data.respond_to?(:draft) ? pr_data.draft : pr_data[:draft]) == false ? 
        (pr_data.respond_to?(:created_at) ? pr_data.created_at : pr_data[:created_at]) : nil,
      author: github_user
    )
    
    pull_request.save!
    
    # Update week associations
    pull_request.ensure_weeks_exist_and_update_associations
  end
  
  def update_progress(repository, page, batch_size)
    total_processed = (page - 1) * BATCH_SIZE + batch_size
    Rails.logger.info "Processed page #{page} for #{repository.name} (#{total_processed} PRs so far)"
    
    # Optionally store progress
    repository.update_column(:sync_progress, total_processed)
  end
  
  def should_continue_fetching?(repository, pull_requests, fetch_all)
    return false if pull_requests.size < BATCH_SIZE # Last page
    
    if fetch_all
      true
    else
      # Check if we've hit PRs we've already seen
      oldest_pr_date = pull_requests.last.updated_at
      repository.last_fetched_at.nil? || oldest_pr_date > repository.last_fetched_at
    end
  end
  
  def finalize_sync(repository)
    repository.update!(
      sync_status: 'completed',
      sync_completed_at: Time.current,
      last_fetched_at: Time.current
    )
    
    # Queue stats calculation
    UpdateRepositoryStatsJob.perform_later(repository.id)
    
    Rails.logger.info "Completed sync for #{repository.name}"
  end
  
  def handle_sync_error(repository, error)
    repository.update!(
      sync_status: 'failed',
      last_sync_error: error.message
    )
    Rails.logger.error "Sync failed for #{repository.name}: #{error.message}"
  end
end