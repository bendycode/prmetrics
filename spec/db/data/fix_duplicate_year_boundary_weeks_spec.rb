require 'rails_helper'
require_relative '../../../db/data/20260108202640_fix_duplicate_year_boundary_weeks'

RSpec.describe FixDuplicateYearBoundaryWeeks do
  let(:migration) { described_class.new }
  let(:repository) { create(:repository) }

  describe '#up' do
    context 'when duplicate weeks exist' do
      let!(:correct_week) { create(:week, :dec_2025_year_boundary, repository: repository) }
      let!(:buggy_week) { create(:week, :dec_2025_year_boundary_buggy, repository: repository) }

      let!(:pr_with_ready_for_review) do
        create(:pull_request, :with_week_associations,
               repository: repository,
               ready_for_review_week: buggy_week)
      end

      let!(:pr_with_merged) do
        create(:pull_request, :with_week_associations,
               repository: repository,
               merged_week: buggy_week)
      end

      it 'merges buggy week into correct week', :aggregate_failures do
        migration.up

        # Reassigns PR associations
        expect(pr_with_ready_for_review.reload.ready_for_review_week).to eq(correct_week)
        expect(pr_with_merged.reload.merged_week).to eq(correct_week)

        # Deletes buggy week, keeps correct week
        expect(Week.exists?(buggy_week.id)).to be false
        expect(Week.exists?(correct_week.id)).to be true
      end
    end

    context 'when buggy week exists without a correct counterpart' do
      let!(:buggy_week_alone) do
        create(:week,
               repository: repository,
               week_number: 202_500,
               begin_date: Date.new(2024, 12, 30),
               end_date: Date.new(2025, 1, 5))
      end

      it 'corrects the week_number without deleting', :aggregate_failures do
        expect { migration.up }.not_to(change(Week, :count))

        # Dec 30, 2024 is a Monday in week 53 of 2024
        expect(buggy_week_alone.reload.week_number).to eq(202_453)
      end
    end

    context 'when no buggy weeks exist' do
      let!(:normal_week) do
        create(:week,
               repository: repository,
               week_number: 202_501,
               begin_date: Date.new(2025, 1, 6),
               end_date: Date.new(2025, 1, 12))
      end

      it 'leaves weeks unchanged', :aggregate_failures do
        original_attributes = normal_week.attributes

        migration.up

        expect(Week.count).to eq(1)
        expect(normal_week.reload.attributes).to eq(original_attributes)
      end
    end
  end
end
