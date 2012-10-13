# encoding: utf-8
#
#  = Name Helpers
#
#  A bunch of high-level helpers for name-related views.
#
#  == Methods
#
#  eol_taxon_link:: Create a link from a name.id and a name.display_name
#
##############################################################################

module NameHelper

  def eol_for_taxon_link(id, name)
    link_to(name.t, :controller => "name", :action => "eol_for_taxon", :id => id)
  end
  
  def classification_section(classification, parents, first_child, children_query)
    head = ""
    lines = []
    if classification
      head = classification.tpl
    else
      for p in parents
        lines.push(rank_as_string(p.rank) + ": " + link_to(p.display_name.t, :action => 'show_name',
                                                          :id => p.id, :params => query_params))
      end
    end
    if first_child
      lines.push(link_to("#{:show_object.t(:type => first_child.rank.to_s)}", :action => 'index_name',
                      :params => query_params(children_query)))
    end
    head + lines.join("<br/>\n")
  end
	
end
