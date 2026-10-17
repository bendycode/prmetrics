class TrackersController < ApplicationController
  def show
    @tracker = policy_scope(Tracker).find(params[:id])
    authorize @tracker
    @report = CycleTimeReport.new(@tracker, clock: clock_param)
  end

  private

  # Only the two clocks' names choose one; anything else, an Array or a Hash
  # included, shows the committed clock.
  def clock_param
    CycleTimeReport::CLOCKS.include?(params[:clock]) ? params[:clock] : CycleTimeReport::DEFAULT_CLOCK
  end
end
