class AccountController < ApplicationController
  skip_before_filter :login_required

  def index
    redirect_to(:action => 'login') unless logged_in? || User.count > 0
  end

  def login
    flash[:notice] = nil
    flash[:alert] = nil
    return unless request.post?
    @login = params[:login]  # add this variable

    # If user exists in LDAP, synchronize with User model
    ldapuser = UserLdap.authenticate(params[:login], params[:password])
    if ldapuser && ldapuser.in_group?( 'team' )
      user = User.find_or_create_by(:login => ldapuser.uid)
      user.attributes = {:name => ldapuser.cn, :email => ldapuser.mail, :birthdate => ldapuser.employeenumber, :password => params[:password], :password_confirmation => params[:password]}
      user.save # this will fail if you add constraints to user.rb, e.g. validates_presence_of -- no good!
      user.set_roles_cached(ldapuser.groups)
      
      AuditLog.create(
        :user_id => user.id,
        :class_name => "User",
        :object_id => user.id,
        :description => "#{user.name} login",
        :ip_address => request.remote_ip,
        :session_id => session[:id]
      )

      self.current_user = User.authenticate(params[:login], params[:password])
    end
    
    if logged_in?
      if params[:remember_me] == "1"
        self.current_user.remember_me
        cookies[:auth_token] = { :value => self.current_user.remember_token, :expires => self.current_user.remember_token_expires_at }
      end

      flash[:error] = nil

      redirect_to(:controller => 'welcome', :action => 'index')
    else
      flash[:error] = 'Incorrect username or password.'
    end
  end

  def logout
    AuditLog.create(
      :user_id     => self.current_user.id,
      :class_name  => "User",
      :object_id   => self.current_user.id,
      :description => "#{self.current_user.name} logout",
      :ip_address  => request.remote_ip,
      :session_id  => session[:id]
    )

    cookies.delete :auth_token
    reset_session
    redirect_back_or_default(:controller => '/account', :action => 'login')
    flash[:notice] = "You have been logged out."
  end

end
