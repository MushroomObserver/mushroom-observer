# encoding: utf-8
ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.

  # Route / to /observer/index
  map.connect '', :controller => 'observer'
  
  # Route /123 to /observer/show_observation/123.
  map.connect ':id', :controller => 'observer', :action => 'show_obs'

  # Route /ajax/method to /api/ajax/method.
  map.connect 'ajax/:method', :controller => 'api', :action => 'ajax'
  map.connect 'ajax/:method/:id', :controller => 'api', :action => 'ajax'
  map.connect 'ajax/:method/:type/:id', :controller => 'api', :action => 'ajax'
  
  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  # map.connect ':controller/service.wsdl', :action => 'wsdl'

  # It's not handling name lookups right for some reason.
  map.connect 'observer/:action/:id', :controller => 'observer',
                                         :action => /lookup_\w+/, :id => /.*/

  # Redirect to observer controller by default.
  map.connect ':controller/:action/:id', :controller => 'observer'

end
