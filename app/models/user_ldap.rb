class UserLdap
  attr_reader :dn
  attr_reader :uid
  attr_reader :cn
  attr_reader :ou
  attr_reader :email
  attr_reader :login
  attr_reader :name    
  attr_reader :mail
  attr_reader :employeenumber
  attr_reader :mobile
  attr_reader :homephone
  attr_reader :street
  attr_reader :l
  attr_reader :st
  attr_reader :postalcode
  

  def initialize(entry)
    entry.each do |attr, v|
      begin
        eval('@' + attr.to_s + '="' + v.first + '"')
      rescue
      end

      # Don't just want the first value, but all of them (as an array)
      @ou = entry['ou']
      @objectclass = entry['objectclass']            

      # Map prettier naems
      @login = entry['uid']
      @email = entry['mail'].to_s      
      @name = entry['cn'].to_s
    end    
  end

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    # Authenticate via LDAP
    @ldap = Ldap.new
    @ldap.auth(login, password)
  end  

  # Update LDAP with new attributes
  def update_these_attributes(attributes)
    # determine which attributes to add/modify
    arr = []
    for attr in UserLdap.attrList
      value = eval('attributes["' + attr.to_s + '"]')

      if ( eval('self.' + attr.to_s) != value )
        arr.push([:replace, eval(':' + attr.to_s), value])
        # validate = @l.replace_attribute self.dn, eval(':' + attr.to_s), value
        # err += attr ' did not save properly<br />' if !validate
      end
    end
    return arr
  end
  
  def self.attrList
    [ 'cn', 'mail', 'employeenumber', 'mobile', 'homephone', 'street', 'l', 'st', 'postalcode' ]
  end

  def groups
    @ldap ||= Ldap.new            
    groups = @ldap.find_groups_of_uid(self.uid)
    groups.collect {|g| g.cn.first }
  end
  
  def groups_to_s
    @ldap ||= Ldap.new            
    groups = @ldap.find_groups_of_uid(self.uid)
    groups.collect {|g| g.cn.first }.join(' ')
  end
  
  def in_group?(group_name)
    @ldap ||= Ldap.new            
    uids = @ldap.find_uids_in_group(group_name)
    uids ? uids.include?(self.uid) : false
  end  

  # Alias for uid
  def login
    self.uid
  end
  
  # Alias for uid
  def id
    self.uid
  end
  
  # Alias for mail
  def mail
    self.email
  end
end
