class DhcpdController < ApplicationController
  include DhcpdLeasesParser

  def show
    render json: { 'mac' => find_mac_by_ip(params[:id]) }
  end

  def leases
    file = "/var/lib/dhcpd/dhcpd.leases"
    if File.exist?(file)
      render file: file, layout: false
    else
      not_found
    end
  end
end
