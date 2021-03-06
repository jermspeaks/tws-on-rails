class AttendanceController < ApplicationController
  before_action :authenticate_user!
  before_action :user_authorized?, only: [:show, :update]
  before_action :host_authorized?, only: [:mark, :cancel]
  before_action :set_attendance, except: [:mark]

  def cancel
    attendance = Attendance.where(tea_time_id: params[:id], id: params[:attendance_id]).first
    if attendance
      attendance.flake!
      redirect_to edit_tea_time_path(attendance.tea_time), alert: "#{attendance.user.name}'s attendance was canceled!"
    else
      redirect_to edit_tea_time_path(attendance.tea_time), alert: "You tried to cancel an attendance that doesn't exist?"
    end
  end

  # POST /tea_times/1/attendance
  def create
    @user = current_user
    @tea_time = TeaTime.find(params[:id])

    @attendance = Attendance.where(tea_time_id: @tea_time.id, user_id: @user.id).first_or_initialize

    # Set status
    if @attendance.tea_time.spots_remaining?
      @attendance.status = :pending
    else
      @attendance.status = :waiting_list
    end

    if @attendance.save

      @attendance.send_mail

      message = @attendance.waiting_list? ?
        "You're on the wait list! Check your email for details." :
        "You're set for tea time! Check your email and add it to your calendar :)"
      return redirect_to profile_path, notice: message
    else
      return redirect_to forbes_city_path(@tea_time.city), alert: "Couldn't register for that, sorry :("
    end
  end

  ############################################
  # Host-related Attendance Actions
  ############################################

  def mark
    @tea_time = TeaTime.find(params[:id])
    respond_to do |format|
      case params[:marking]
      when 'email'
        if params[:email_sent] == 'true'
          if @tea_time.advance_state!
            format.html { redirect_to host_tasks_path, notice: 'All done!' }
            format.json { render json: @tea_time }
          else
            format.html { redirect_to :back, alert: "That didn't work. Try again?" }
            format.json { render json: { errors: @tea_time.errors.full_messages } }
          end
        end
      when 'attendance'
        tea_time_params = params.fetch(:tea_time, {}).permit!
        if @tea_time.update!(tea_time_params) && @tea_time.advance_state!
          format.html { redirect_to host_tasks_path, notice: 'Thanks for taking
                        attendance! Now send an email to your attendees :)' }
          format.json { render json: @tea_time }
        else
          format.html {redirect_to :back, alert: 'Uh-oh. Something went wrong.
                       Care to try again?' }
          format.json { render json: { errors: @tea_time.errors.full_messages } }
        end
      when 'edit_attendance'
        @tea_time.update(followup_status: "pending")
        format.html { redirect_to :back, notice: "OK, care to mark again?" }
      end
    end
  end

  ############################################
  # User-related Attendance Actions
  ############################################
  def show
    use_new_styles
    render :flake, layout: !request.xhr?
  end

  # PUT /tea_times/1/attendance/2
  # TODO Looks like this ONLY "flakes" the attenance
  # It should probably look at params to see what the update
  # request is trying to do.


  def update
    respond_to do |format|
      if @attendance.flake!({reason: params[:attendance][:reason]})
        format.html { redirect_to profile_path, notice: 'Your spot is now open for someone else!' }
        format.json { render :show, status: :created, location: @tea_time }
      else
        format.html { redirect_to profile_path }
        format.json { render json: @attendance.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_attendance
    @tea_time = params[:id]
    @attendance = Attendance.find_by(tea_time: @tea_time, user: current_user)
  end

  def user_authorized?
    if !(can? :update, (@attendance || Attendance))
      redirect to :back, error: "I can't let you do that Dave"
    end
  end

  def host_authorized?
    if !(can? :manage, (@tea_time || TeaTime))
      redirect to :back, error: "I can't let you do that Dave"
    end
  end
end
