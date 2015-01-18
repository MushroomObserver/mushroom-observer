MushroomObserver::Application.routes.draw do
  # map.resources :publications
  match 'publications/:id/destroy' => 'publications#destroy'
  resources :publications
  
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Default page is /observer/index.
  # map.connect '', :controller => 'observer', :action => 'index'
  root :to => "observer#index"
  
  # Route /123 to /observer/show_observation/123.
  # map.connect ':id', :controller => 'observer', :action => 'show_observation', :id => /\d+/
  match ':id' => "observer#show_observation", :constraints => { :id => /\d+/ }
  
  # Short-hand notation for AJAX methods.
  # map.connect 'ajax/:action/:type/:id', :controller => 'ajax', :id => /\S.*/
  match 'ajax/:action/:type/:id' => "ajax", :constraints => { :id => /\S.*/ }

  # Default action for any controller is 'index'.
  # map.connect ':controller', :action => 'index'
  match ':controller' => ':controller#index'
  
  # Standard routes.
  # map.connect ':controller/:action'
  match ':controller/:action'
  # map.connect ':controller/:action/:id', :id => /\d+/
  match ':controller/:action/:id', :constraints => { :id => /\d+/ }
  
  # Accept non-numeric ids for the lookup_xxx actions.
  # map.connect ':controller/:action/:id', :action => /lookup_\w+/
  match ':controller/:action/:id', :action => /lookup_\w+/

end
