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
    head = safe_empty
    lines = []
    if classification
      head = classification.tpl
    else
      # TODO: Create test that covers this section
      for p in parents
        lines.push(rank_as_string(p.rank).html_safe + ": " +
          link_with_query(p.display_name.t, :action => 'show_name', :id => p.id))
      end
    end
    if first_child
      lines.push(link_to("#{:show_object.t(:type => first_child.rank.to_s)}",
        add_query_param({:action => 'index_name'}, children_query)))
    end
    head + lines.join("<br/>\n").html_safe
  end
	
end
