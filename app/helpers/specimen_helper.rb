module SpecimenHelper

  def observation_links(specimen)
    specimen.observations.map {|obs|
      link_to(obs.unique_format_name.t, :controller => :observer,
              :action => :show_observation, :id => obs.id)
    }.safe_join(', ')
  end

  def herbarium_link(herbarium)
    :HERBARIUM.ths + ': ' + link_to(herbarium.name, :controller => :herbarium,
                                    :action => :show_herbarium, :id => herbarium.id)
	end
end
