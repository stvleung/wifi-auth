class Person
  attr_reader :dn
  attr_reader :objectclass
  attr_reader :uid
  attr_reader :cn
  attr_reader :mail
  attr_reader :employeenumber
  attr_reader :mobile
  attr_reader :homephone
  attr_reader :street
  attr_reader :l
  attr_reader :st
  attr_reader :postalcode
  attr_reader :ou
  attr_reader :userpassword
  
  
  # validates_presence_of :mail

  def initialize(entry)
    entry.each{ |attr, v|
      begin
        eval('@' + attr.to_s + '="' + v.first + '"')
      rescue
      end
      
      # don't just want the first value, but all of them (as an array)
      @ou = entry['ou']
      @objectclass = entry['objectclass']      
    }
    
    @ldap ||= Ldap.new        
  end
  
  def update_these_attributes(attributes)
    # determine which attributes to add/modify
    arr = []
    for attr in Person.attrList

      value = eval('attributes["' + attr.to_s + '"]')
      
      if ( eval('self.' + attr.to_s) != value )
        arr.push([:replace, eval(':' + attr.to_s), value])
        # validate = @l.replace_attribute self.dn, eval(':' + attr.to_s), value
        # err += attr ' did not save properly<br />' if !validate 
      end
    end
    return arr
  end
  
  def update_group_membership(groups)
    arr = []
    # check if we need to add or delete a given group
    @ldap.all_groups.each do |group|
      if self.in_group?(group) && (!groups || groups.empty? || !groups.has_key?(group))
        # delete group
        @ldap.remove_from_group(self.uid, group)
      elsif groups && !self.in_group?(group) && groups.has_key?(group)
        # add group
        @ldap.add_to_group(self.uid, group)
      end
    end
    return arr
  end
  
  def add_posix_account_attributes(highest_uid_number, highest_gid_number)
    arr = []
    arr << [:add, :uidnumber, "#{highest_uid_number + 1}"]
    arr << [:add, :gidnumber, "#{highest_gid_number + 1}"]    
    arr << [:add, :homedirectory, '/home/' + self.uid]        
    arr << [:add, :objectclass, ['posixAccount','shadowAccount']]
    arr
  end
  
  def validate_add_to_group(group_name)
    return 'Group is not specified' if group_name.nil?
    return '<em>' + group_name + '</em> is not a valid group' unless @ldap.find_group(group_name)
    return self.cn + ' already belongs to ' + group_name if self.in_group?(group_name)
    return true
  end
  
  def validate_remove_from_group(group_name)
    return 'Group is not specified' if group_name.nil?
    return '<em>' + group + '</em> is not a valid group' unless @ldap.find_group(group_name)
    return self.cn + ' does not belong in ' + group_name unless self.in_group?(group_name)
    return true
  end
  
  # Add this person to a group
  def add_to_group(group_name)
    @ldap.add_to_group(self.uid, group_name)
  end

  # Remove this person from a group
  def remove_from_group(group_name)
    @ldap.remove_from_group(self.uid, group_name)
  end

  
  def is_admin?
    self.in_group?('gracewiki_admin')
  end
  
  def the_same_as?(person)
    self.uid == person.uid
  end
  
  def groups
    @groups ||= @ldap.find_groups_of_uid(self.uid)
  end
  
  def groups_to_s
    self.groups.join(' ')
  end
  
  def in_group?(group_name)
    self.groups.include?(group_name)
  end
  
  def birthdate
    if self.birthdate?
      return Time.parse(self.employeenumber)
    else
      return nil
    end
  end
  
  def birthdate?
    #return false # Added by conrad, 10/28/07 -- getting an argument out of length error when doing the code below
    if self.employeenumber && self.employeenumber.length == 10
      return true
    else 
      return false
    end
  end
  
  def mini_address
    str = self.street
    if self.l && str
      str += ', ' + self.l
    elsif self.l
      str = self.l
    end
    return str
  end
  
  def end_address
    str = self.st.to_s
    str += ', ' + self.postalcode if self.postalcode
    return str
  end
  
  def full_address 
    str = self.mini_address.to_s + ' ' + self.end_address.to_s
  end
  
  # Return true if a similar entry exists in the ldao entries array
  def find_similar(entries)
    count = 0
    entries.each do |entry|
      p = Person.new(entry)     
      
      begin
        if ((p.cn.downcase == self.cn.downcase) || (p.mail.downcase == self.mail.downcase))
          count = count + 1
          return true if count > 1
        end
      rescue NoMethodError
      end        
    end
    return false
  end
  
  # self methods
    
  def self.attrHash
    { 'uid' => 'Username',
      'cn' => 'Name',
      'mail' => 'E-mail',
      'employeenumber' => 'Birthday',
      'mobile' => 'Cell Phone #',
      'homephone' => 'Home Phone #',
      'street' => 'Street',
      'l' => 'City',
      'st' => 'State',
      'postalcode' => 'Zip Code',
      'ou' => 'Groups'
      }
  end
  
  def self.attrList
    [ 'cn', 'mail', 'employeenumber', 'mobile', 'homephone', 'street', 'l', 'st', 'postalcode' ]
  end
  
  # str should be a string of numbers
  def self.phone(str)
    if str && str.length >= 10
      return str
    else
      return ''
    end
  end
  
  def self.phone_triplet(p1, p2, p3)
    if p1 && p2 && p3
      return p1 + ' ' + p2 + ' ' + p3
    else
      return nil
    end
  end
  
  def self.phone_format(str, prefix)
    if str && str.length == 10
      return prefix + '(' + str[0..2] + ')-' + str[3..5] + '-' + str[6..9] + '<br />'
    elsif str && str.length == 12
      return prefix + '(' + str[0..2] + ')-' + str[4..6] + '-' + str[8..11] + '<br />'
    else
      return nil
    end
  end

end
