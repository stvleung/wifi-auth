require 'digest/sha1'
class User < ActiveRecord::Base
  # Virtual attribute for the unencrypted password
  attr_accessor :password

  validates_presence_of     :login, :email
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :login, :within => 3..40
  validates_length_of       :email, :within => 3..100
  validates_uniqueness_of   :login, :case_sensitive => false
  before_save :encrypt_password

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    u = find_by_login(login) # need to get the salt
    u && u.authenticated?(password) ? u : nil
  end

  # Encrypts some data with the salt.
  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    self.remember_token_expires_at = 2.weeks.from_now.utc
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
  end

  # Reset the password
  def forgot_password
    @forgotten_password = true
    self.make_password_reset_code
  end

  # Set the password reset
  def set_password_reset
    self.make_password_reset_code
  end

  def reset_password
    # First update the password_reset_code before setting the
    # reset_password flag to avoid duplicate email notifications.
    update_attributes(:password_reset_code => nil)
    @reset_password = true
  end

  def recently_reset_password?
    @reset_password
  end

  def recently_forgot_password?
    @forgotten_password
  end

  # Return the first name of the user
  def first_name
    self.name.split(' ').first.titlecase
  end
  
  def display_name
    self.commonly_known_as || self.name
  end

  # Aliases
  def self.find_by_id(login)
    self.find(:first, :conditions => ['login = ?', login])
  end

  # Does this user have this role?
  def has_role?(role)
    self.roles_cached.nil? ? false : self.roles_cached.split(',').include?(role)
  end

  # Role query methods

  def is_member?
    has_role?('member')
  end

  def is_team?
    has_role?('team')
  end

  def is_staff?
    has_role?('staff')
  end

  # ROLES

  # Set the roles this user is a part of based on what is coming in LDAP.  Create roles if necessary
  def set_roles_cached(ldap_roles_arr)
    # Cache the roles as a concatenated string into the user object
    self.roles_cached = ldap_roles_arr.join(',')
    save
  end

  def empty_profile?
    return self.peer_class.nil? || self.gender.nil?
  end

  # Check if username exists, return true if it does
  def self.validate_username(login)
    ldap_user = Ldap.new.find(login)
    local_user = User.find(:first, :conditions => ["login = ?", login])
    return ldap_user || local_user
  end

  # this works only because there is only one user pertaining to a reques
  def self.current
    Thread.current[:user]
  end

  def self.current=(user)
    Thread.current[:user] = user
  end

  def self.simple_record_name(id)
    User.find(id).name
  end

  protected
  # before filter
  def encrypt_password
    return if password.blank?
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    self.crypted_password = encrypt(password)
  end
    
  def password_required?
    crypted_password.blank? || !password.blank?
  end

  # Save a random password as a reset code
  def make_password_reset_code
    self.password_reset_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
  end

end
