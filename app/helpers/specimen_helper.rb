module SpecimenHelper

  def observation_links(specimen)
    specimen.observations.map {|obs|
      link_to(obs.format_name.t,
    					:controller => 'observer', :action => 'show_observation', :id => obs.id)
    }.join(', ')
  end

end
