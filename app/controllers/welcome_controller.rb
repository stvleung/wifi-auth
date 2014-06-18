class WelcomeController < ApplicationController
  include DhcpdLeasesParser

  def index
    ip = request.remote_ip
    system("ping -qnrc1 #{ip} &>/dev/null")
    mac = IO.popen("ip neigh show #{ip}").first.split(/\s/)[4]
    mac ||= Socket.gethostname == $router['hostname'] \
      ? find_mac_by_ip(ip) \
      : get_mac_by_ip_from_router($router['hostname'], ip)
    render locals: {ip: ip, mac: mac}
  end
end
