namespace :fix do
  desc "Remove duplicate pull request and review records"
  task duplicates: :environment do
    puts "🔍 Finding duplicate pull request records..."

    total_removed = 0

    Repository.find_each do |repository|
      duplicates = repository.pull_requests
        .group(:number)
        .having("COUNT(*) > 1")
        .count

      next if duplicates.empty?

      puts "\n📁 Repository: #{repository.name}"
      puts "  Found #{duplicates.size} PR numbers with duplicates"

      duplicates.each do |pr_number, count|
        puts "  PR ##{pr_number}: #{count} copies"

        # Get all copies of this PR
        prs = repository.pull_requests.where(number: pr_number).order(:updated_at)

        # Keep the most recently updated one
        keeper = prs.last
        to_remove = prs - [keeper]

        puts "    Keeping ID: #{keeper.id} (updated: #{keeper.updated_at})"
        to_remove.each do |pr|
          puts "    Removing ID: #{pr.id}"
          pr.destroy
          total_removed += 1
        end
      end
    end

    puts "\n✅ Removed #{total_removed} duplicate PR records"

    # Now handle review duplicates
    puts "\n🔍 Finding duplicate review records..."
    review_duplicates_removed = 0

    # Find all reviews grouped by uniqueness criteria
    duplicate_reviews = Review.select(:pull_request_id, :author_id, :submitted_at, :state)
                             .group(:pull_request_id, :author_id, :submitted_at, :state)
                             .having("COUNT(*) > 1")

    duplicate_reviews.each do |dup|
      reviews = Review.where(
        pull_request_id: dup.pull_request_id,
        author_id: dup.author_id,
        submitted_at: dup.submitted_at,
        state: dup.state
      ).order(:created_at)

      keeper = reviews.first
      to_remove = reviews - [keeper]

      if to_remove.any?
        pr = PullRequest.find(dup.pull_request_id)
        author = Contributor.find_by(id: dup.author_id)
        puts "  PR ##{pr.number}, Author: #{author&.username || 'unknown'}, Time: #{dup.submitted_at}: removing #{to_remove.size} duplicates"

        to_remove.each(&:destroy)
        review_duplicates_removed += to_remove.size
      end
    end

    puts "\n✅ Removed #{review_duplicates_removed} duplicate review records"
    puts "\n📊 Total duplicates removed: #{total_removed + review_duplicates_removed}"
  end

  desc "Preview duplicate pull requests without removing them"
  task preview_duplicates: :environment do
    puts "🔍 Previewing duplicate pull request records..."

    total_duplicates = 0

    Repository.find_each do |repository|
      duplicates = repository.pull_requests
        .group(:number)
        .having("COUNT(*) > 1")
        .count

      next if duplicates.empty?

      puts "\n📁 Repository: #{repository.name}"

      duplicates.each do |pr_number, count|
        total_duplicates += (count - 1)

        prs = repository.pull_requests
          .where(number: pr_number)
          .order(:updated_at)
          .select(:id, :number, :gh_merged_at, :created_at, :updated_at)

        puts "\n  PR ##{pr_number} has #{count} copies:"
        prs.each_with_index do |pr, i|
          status = (i == prs.length - 1) ? "KEEP" : "REMOVE"
          puts "    [#{status}] ID: #{pr.id}, merged: #{pr.gh_merged_at || 'not merged'}, updated: #{pr.updated_at}"
        end
      end
    end

    puts "\n📊 Total duplicate records that would be removed: #{total_duplicates}"
  end
end