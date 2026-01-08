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

      it 'reassigns PR associations from buggy week to correct week' do
        migration.up

        expect(pr_with_ready_for_review.reload.ready_for_review_week).to eq(correct_week)
        expect(pr_with_merged.reload.merged_week).to eq(correct_week)
      end

      it 'deletes the buggy week' do
        expect { migration.up }.to change { Week.exists?(buggy_week.id) }.from(true).to(false)
      end

      it 'keeps the correct week' do
        expect { migration.up }.not_to(change { Week.exists?(correct_week.id) })
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

      it 'updates the week_number to the correct value' do
        # Dec 30, 2024 is a Monday in week 53 of 2024
        expect { migration.up }
          .to change { buggy_week_alone.reload.week_number }
          .from(202_500).to(202_453)
      end

      it 'does not delete the week' do
        expect { migration.up }.not_to(change(Week, :count))
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

      it 'does not modify any weeks' do
        expect { migration.up }.not_to(change { normal_week.reload.attributes })
      end

      it 'does not delete any weeks' do
        expect { migration.up }.not_to(change(Week, :count))
      end
    end
  end
end
