class Week < ApplicationRecord
  belongs_to :repository

  validates :week_number, presence: true, uniqueness: { scope: :repository_id }
  validates :begin_date, :end_date, presence: true
end
