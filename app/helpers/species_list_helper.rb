# encoding: utf-8
#
#  = Species List Helpers
#
#  A bunch of high-level helpers for species list related views.
#
#  == Methods
#
#  label_rows:: Formats an ordered list of label/value pairs for a label
#
##############################################################################

module SpeciesListHelper
  def label_rows(rows)
    rows.map do |label, value|
      content_tag(:b, label + ':') + ' ' + value.to_s + safe_br
    end.safe_join
  end	
end
