class WelcomeController < ApplicationController
  include DhcpdLeasesParser

  def index
  	@ip = request.remote_ip
  	@mac = Socket.gethostname == $router['hostname'] \
      ? find_mac_by_ip(@ip) \
      : get_mac_by_ip_from_router($router['hostname'], @ip)
  end
end
