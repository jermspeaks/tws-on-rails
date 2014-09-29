class AttendanceController < ApplicationController
  # PUT /tea_times/1/attendance/2

  # TODO Looks like this ONLY "flakes" the attenance
  # It should probably look at params to see what the update
  # request is trying to do.
  def update
    @tea_time = params[:id]
    @attendance = Attendance.find_by(tea_time: @tea_time, user: current_user)

    respond_to do |format|
      if @attendance.flake!({reason: params[:reason]})
        format.html { redirect_to profile_path, notice: 'Your spot is now open for someone else!' }
        format.json { render :show, status: :created, location: @tea_time }
      else
        format.html { redirect_to profile_path }
        format.json { render json: @attendance.errors, status: :unprocessable_entity }
      end
    end
  end
end