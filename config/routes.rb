ActionController::Routing::Routes.draw do |map|
  # Add your own custom routes here.
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Here's a sample route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"

  # Ensure that '' goes to /observer/index
  map.connect '', :controller => 'observer'
  
  # Route /# to /observer/show_observation/#
  map.connect ':id', :controller => 'observer', :action => 'show_observation'
  
  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  # map.connect ':controller/service.wsdl', :action => 'wsdl'

  # Handle the checklist reports.
  map.connect ':controller/:action.:ext'

  # Redirect to observer controller by default
  map.connect ':controller/:action/:id', :controller => 'observer'

end
