class ApplicationController < ActionController::Base
  include AuthenticatedSystem
  include ::SslRequirement

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # If you want "remember me" functionality, add this before_filter to Application Controller
  before_filter :login_from_cookie

  # Require login for every controller
  before_filter :login_required


  # Session expiration controls
  before_filter :logout_if_expired, :except => [ :login, :logout ]
  before_filter :update_activity_time, :except => [ :logout, :check_session_expiry ]

  # Logout if the session has expired
  def logout_if_expired
    expire_time = session[:expires_at] || Time.now
    session_time_left = (expire_time - Time.now).to_i

    unless session_time_left > 0
      redirect_back_or_default(:controller => '/account', :action => 'logout')
    end
  end

  # Returns the number of seconds that session is going to expire
  def check_session_expiry
  	expire_time = session[:expires_at] || Time.now
  	session_time_left = (expire_time - Time.now).to_i

  	render :json => session_time_left
  end

  def extend_session
  	render :nothing => true, :status => 200, :content_type => 'text/html'
  end

  # Extend session upon activity
  def update_activity_time
  	session[:expires_at] = Rails.env.development? ? 8.hours.from_now : 20.minutes.from_now
  end

  # Conventional way to implement 404
  def not_found
  	raise ActionController::RoutingError.new('Not Found')
  end
end
