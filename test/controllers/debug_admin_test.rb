# frozen_string_literal: true

require("test_helper")

class DebugAdminTest < FunctionalTestCase
  tests LocationsController

  def test_debug_admin_mode
    login("mary")
    make_admin("mary")
    
    puts "Session admin before request: #{@request.session[:admin].inspect}"
    
    location = locations(:albion)
    get(:show, params: { id: location.id })
    
    puts "Session admin after request: #{session[:admin].inspect}"
    puts "Response includes destroy button: #{@response.body.include?("turbo-method=\"delete\"")}"
    puts "in_admin_mode? in controller: #{@controller.send(:in_admin_mode?).inspect}"
  end
end
