require 'rails_helper'
require_relative '../../../db/data/20260108202640_fix_duplicate_year_boundary_weeks'

RSpec.describe FixDuplicateYearBoundaryWeeks do
  let(:migration) { described_class.new }
  let(:repository) { create(:repository) }

  describe '#up' do
    context 'when duplicate weeks exist' do
      let!(:correct_week) do
        create(:week,
               repository: repository,
               week_number: 202_552,
               begin_date: Date.new(2025, 12, 29),
               end_date: Date.new(2026, 1, 4))
      end

      let!(:buggy_week) do
        create(:week,
               repository: repository,
               week_number: 202_600,
               begin_date: Date.new(2025, 12, 29),
               end_date: Date.new(2026, 1, 4))
      end

      let!(:pr_with_ready_for_review) do
        pr = create(:pull_request, repository: repository)
        pr.update_column(:ready_for_review_week_id, buggy_week.id)
        pr
      end

      let!(:pr_with_merged) do
        pr = create(:pull_request, repository: repository)
        pr.update_column(:merged_week_id, buggy_week.id)
        pr
      end

      it 'reassigns PR associations from buggy week to correct week' do
        migration.up

        expect(pr_with_ready_for_review.reload.ready_for_review_week_id).to eq(correct_week.id)
        expect(pr_with_merged.reload.merged_week_id).to eq(correct_week.id)
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
