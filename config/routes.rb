# encoding: utf-8
ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.

  # Default page is /observer/index.
  map.connect '', :controller => 'observer', :action => 'index'
  # was: map.connect '', :controller => 'observer' (??!)

  # Default action for any controller is 'index'.
  map.connect ':controller', :action => 'index'
  # was: map.connect 'pivotal', :controller => 'pivotal', :action => 'index'

  # Route /123 to /observer/show_observation/123.
  map.connect ':id', :controller => 'observer', :action => 'show_observation', :id => /\d+/
  map.connect 'obs', :controller => 'observer', :action => 'show_observation'
  map.connect 'obs/:id', :controller => 'observer', :action => 'show_observation', :id => /\d+/
  # was: map.connect ':id', :controller => 'observer', :action => 'show_obs'
  # was: map.connect 'obs/:id', :controller => 'observer', :action => 'show_observation'

  # Short-hand notation for AJAX methods.
  map.connect 'ajax/:method', :controller => 'api', :action => 'ajax'
  map.connect 'ajax/:method/:id', :controller => 'api', :action => 'ajax'
  map.connect 'ajax/:method/:type/:id', :controller => 'api', :action => 'ajax'

  # Standard routes.
  map.connect ':controller/:action'
  map.connect ':controller/:action/:id', :id => /\d+/
  # was: map.connect ':controller/:action/:id', :controller => 'observer' (??!)

  # Accept non-numeric ids for the lookup_xxx actions.
  map.connect ':controller/:action/:id', :action => /lookup_\w+/
  # was: map.connect 'observer/:action/:id', :controller => 'observer', :action => /lookup_\w+/, :id => /.*/
end
