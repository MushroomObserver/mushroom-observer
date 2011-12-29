# encoding: utf-8
#
#  = API and AJAX Controller
#
#  This controller handles the XML interface.
#
#  == Actions
#
#  xml_rpc::      Entry point for XML-RPC requests.
#  <table>::      Entry point for REST requests.
#  ajax::         Entry point for AJAX requests.
#  test::         Test action that just renders "test".
#
################################################################################

class ApiController < ApplicationController
  require_dependency 'controllers/api_controller/api'
  require_dependency 'controllers/api_controller/ajax'
  require_dependency 'controllers/api_controller/auto_complete'

  # Disable all filters except set_locale.
  skip_filter   :browser_status
  skip_filter   :check_user_alert
  skip_filter   :autologin
  skip_filter   :extra_gc

  before_filter :disable_link_prefetching
  before_filter { User.current = nil }

  # Used for testing.
  def test
    render(:text => 'test', :layout => false)
  end
end
