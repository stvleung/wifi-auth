class Ldap
  require 'net/ldap'
  
  attr_reader :base, :ldap

  def initialize()
    @ldap = self.establish_connection
  end
  
  # admin sees all entries
  def all_entries(return_attrs = '*', options = { 'sort_by' => 'first', 'filter' => 'cn=*' })
    options['filter'] = 'cn=*' if options['filter'].nil?

    entries = @ldap.search( :base => $ldap_usersdn, :filter => options['filter'], :attributes => return_attrs )
    if options['sort_by'] == 'birthday'
      entries.sort! {|a,b| (a['employeenumber'].to_s[5..9] || '99-99') <=> (b['employeenumber'].to_s[5..9] || '99-99')}
    elsif options['sort_by'] != nil
      entries.sort! {|a,b| a['cn'].to_s.downcase <=> b['cn'].to_s.downcase}
    end
  end
  
  # non-admin sees only subset of entries
  def some_entries(sort_by = 'first')
    self.all_entries('*', { 'filter' => '(&(cn=*)(!(ou=tester)))', 'sort_by' => sort_by })
  end
  
  def find(uid)
    # this is necessary because NetLDAP's "search" doesn't natively accept spaces in strings
    filter = Net::LDAP::Filter.eq('uid', uid)
    entry = @ldap.search( :base => $ldap_usersdn, :filter=> filter )
    if entry && entry.first
      person = Person.new(entry.first)
    else
      return nil
    end
  end
  
  # Find an entry based on a uid
  def find_entry(uid)
    # this is necessary because NetLDAP's "search" doesn't natively accept spaces in strings
    filter = Net::LDAP::Filter.eq('uid', uid)
    entry = @ldap.search( :base => $ldap_usersdn, :filter=> filter )
    entry.first if entry
  end
  
  # Find a group, return the cn
  def find_group(name)
    @ldap.search( :base => $ldap_groupdn, :filter => "(&(cn=#{name})(objectClass=posixGroup))", :attributes => 'cn' ).first
  end
  
  # Return all groups cn's, alpha-sorted
  def all_groups
    @ldap.search( :base => $ldap_groupdn, :filter => '(&(cn=*)(objectClass=posixGroup))', :attributes => 'cn' ).collect{|g| g[:cn].first}.sort{|x,y| x <=> y}
  end
  
  # Is this uid in a group
  def in_group?(uid, group_name)
    @ldap.search( :base => $ldap_groupdn, :filter => "(&(memberUid=#{uid})(cn=#{group_name})(objectClass=posixGroup))", :attributes => 'memberUid').present?
  end
  
  # Add uid to group
  def add_to_group(uid, group_name)
    ops = [[:add, :memberuid, uid]]
    groupdn = self.find_group(group_name).dn
    @ldap.modify :dn => groupdn, :operations => ops
  end

  # Remove uid from group
  def remove_from_group(uid, group_name)
    ops = [[:delete, :memberuid, uid]]
    groupdn = self.find_group(group_name).dn
    @ldap.modify :dn => groupdn, :operations => ops
  end
    
  # Rename an existing group
  def rename_group(group_name, new_name)
    groupdn = self.find_group(group_name).dn
    @ldap.rename :olddn => groupdn, :newrdn => "cn=#{new_name}"
  end
  
  # Find all user entries in a group
  def find_users_in_group(name)
    entries = []
    self.find_uids_in_group(name).each do |uid|
      entries << self.find_entry(uid)
    end
    entries
  end
  
  # Find all the uids in a group
  def find_uids_in_group(name)
    group = @ldap.search( :base => $ldap_groupdn, :filter => "(&(cn=#{name})(objectClass=posixGroup))", :attributes => 'memberUid' ).first
    if group
      uids = []
      group[:memberuid].sort{|x,y| x.downcase <=> y.downcase}.each do |uid|
        uids << uid
      end
      uids
    end
  end
  
  # Find all the groups for a given uid, return the cn of the group
  def find_groups_of_uid(uid)
    @groups ||= @ldap.search( :base => $ldap_groupdn, :filter => '(&(cn=*)(objectClass=posixGroup))', :attributes => ['cn','memberUid'] )   
    @member_of_groups ||= Hash.new    
    unless @member_of_groups[uid]
      arr = []
      @groups.each do |g|
        arr << g.cn.first if g[:memberuid].include?(uid)
      end  
      @member_of_groups[uid] = arr
    else
      @member_of_groups[uid]
    end
  end
  
  def auth(login, pw)
    auth_ldap = self.establish_connection
    auth_ldap.authenticate 'uid=' + login +',' + $ldap_usersdn, pw
    auth_ldap.bind ? self.find(login) : nil
  end
  
  def create_user(login, pw, first_name, last_name, email)
    attr = {
      :objectclass => ['person', 'inetOrgPerson', 'extensibleObject','posixAccount','shadowAccount'],
      :sn => last_name,
      :cn => first_name + " " + last_name,
      :uid => login,
      :uidnumber => "#{self.highest_uid_number + 1}",
      :gidnumber => "#{self.highest_gid_number + 1}",      
      :homedirectory => '/home/' + login,
      :userpassword => '{MD5}' + Base64.encode64(Digest::MD5.digest(pw)).chomp,
      :mail => email
    }
    
    @ldap.add( :dn => 'uid=' + login + ',' + $ldap_usersdn, :attributes => attr )
    if @ldap.get_operation_result.code != 0
      @ldap.get_operation_result.message
    elsif @ldap.bind
      self.find(login)
    else
      nil
    end
  end
  
  def create_group(name)
    attr = {
      :objectclass => ['posixGroup'],
      :cn => name,
      :gidnumber => "#{self.highest_gid_number + 1}"
    }
    
    # Set the group distinguished name
    group_dn = 'cn=groups,' + $ldap_basedn
    
    @ldap.add( :dn => 'cn=' + name + ',' + group_dn, :attributes => attr )    
  end
  
  def delete_user(dn)
    @ldap.delete( :dn => dn)
    @ldap.get_operation_result
  end

  def delete_group(group_name)
    groupdn = self.find_group(group_name).dn    
    @ldap.delete( :dn => groupdn)
    @ldap.get_operation_result
  end
     
  # Implements an auto-incrementer for uidNumber
  def highest_uid_number
    entries = @ldap.search( :base => $ldap_usersdn, :filter => '(uidnumber=*)', :attributes => 'uidNumber' )
    unless entries.empty?
      # Get the highest number
      entries.collect{|e| e.uidnumber.first}.max.to_i
    else
      1000001
    end
  end

  # Implements an auto-incrementer for gidNumber
  def highest_gid_number
    entries = @ldap.search( :base => $ldap_basedn, :filter => '(gidnumber=*)', :attributes => 'gidNumber' )
    unless entries.empty?
      # Get the highest number
      entries.collect{|e| e.gidnumber.first}.max.to_i
    else
      1000001
    end
  end

  protected
  def establish_connection
    hsh = {:host => $ldap_host, :port => $ldap_port, :base => $ldap_basedn }
    
    # Add TLS encryption if port 636
    hsh[:encryption] = {:method => :simple_tls} if $ldap_port == 636
    
    hsh[:auth] = { 
      :method => :simple, 
      :username => $ldap_username, 
      :password => $ldap_password }
    return Net::LDAP.new( hsh )
  end
end
