class NameController < ApplicationController
  def map
    name_id = params[:id]
    @name = Name.find(name_id)
    locs = name_locs(name_id)
    @synonym_data = []
    synonym = @name.synonym
    if synonym
      for n in synonym.names
        if n != @name
          syn_locs = name_locs(n.id)
          for l in syn_locs
            unless locs.member?(l)
              locs.push(l)
            end
          end
        end
      end
    end
    @map = nil
    @header = nil
    if locs.length > 0
      @map = make_map(locs)
      @header = "#{GMap.header}\n#{@map.to_html}"
    end
  end
  
  def name_locs(name_id)
    Location.find(:all, {
      :include => :observations,
      :conditions => ["observations.name_id = ? and observations.is_collection_location = true", name_id]
    })
  end
end
