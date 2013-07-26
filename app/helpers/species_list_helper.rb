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
      "<b>#{label}:</b> #{value}<br/>"
    end.join
  end	
end
