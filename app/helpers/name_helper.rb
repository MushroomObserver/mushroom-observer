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
  
end
