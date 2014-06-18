require 'date'
require 'open-uri'

module DhcpdLeasesParser
  def parse_leases(file)
    mac = Hash.new
    lease_end = Hash.new
    epoch_0 = Time.at(0).to_datetime

    @lease_end = epoch_0
    ip = nil
    open(file).each do |line|
      case line
      when /^lease ([\d\.]+) {$/
        ip = $1
      when /hardware ethernet ([\h:]+);$/
        if @lease_end > (lease_end[ip] || epoch_0)
          mac[ip] = $1
          lease_end[ip] = @lease_end
        end
      when /ends \d ([\d:\/ ]+);$/
        @lease_end = DateTime.parse $1
      when /ends never;$/
        @lease_end = DateTime.parse('2099-12-31')
      when /\}$/
        @lease_end = epoch_0
      else
        next
      end
    end

    return mac
  end

  # Run this on the router
  def find_mac_by_ip(ip)
    mac = parse_leases("/var/lib/dhcpd/dhcpd.leases")
    return mac[ip]
  end

  # Run this from anywhere
  def get_mac_by_ip_from_router(router, ip)
    mac = parse_leases("http://#{router}/dhcpd/dhcpd.leases")
    return mac[ip]
  end
end
