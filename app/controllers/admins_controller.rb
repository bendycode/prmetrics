class AdminsController < ApplicationController
  before_action :set_admin, only: [:destroy]

  def index
    @admins = Admin.all.order(:email)
  end

  def new
    @admin = Admin.new
  end

  def create
    @admin = Admin.invite!(admin_params, current_admin)
    
    if @admin.errors.empty?
      redirect_to admins_path, notice: "Invitation sent to #{@admin.email}"
    else
      render :new
    end
  end

  def destroy
    if can_delete_admin?
      @admin.destroy
      redirect_to admins_path, notice: 'Admin was successfully removed.'
    else
      redirect_to admins_path, alert: 'Cannot delete the last admin.'
    end
  end

  private

  def set_admin
    @admin = Admin.find(params[:id])
  end

  def admin_params
    params.require(:admin).permit(:email)
  end
  
  def can_delete_admin?
    # If this is a pending invitation, always allow deletion
    return true if @admin.invitation_accepted_at.nil?
    
    # For active admins, check if there are other active admins
    # Count admins that have accepted their invitation AND are not the current one being deleted
    other_active_admins = Admin.where.not(id: @admin.id)
                               .where.not(invitation_accepted_at: nil)
                               .count
    
    other_active_admins > 0
  end
end