# encoding: utf-8
#
#  = Textile Helpers
#
#  These are some legacy helpers that we used to use for Textile formatting
#  in our views.  We now prefer the String and Symbol extensions.  See also
#  Textile#textilize.
#
#  *NOTE*: These are all included in ApplicationHelper.
#
#  == Methods
#
#  textilize::                    Turn Textile into HTML.
#  textilize_without_paragraph::  Turn one-liner Textile into HTML.
#
##############################################################################

module ApplicationHelper::Textile

  # Override Rails method of the same name.  Just calls our
  # Textile#textilize_without_paragraph method on the given string.
  def textilize_without_paragraph(str, do_object_links=false)
    Textile.textilize_without_paragraph(str, do_object_links)
  end

  # Override Rails method of the same name.  Just calls our Textile#textilize
  # method on the given string.
  def textilize(str, do_object_links=false)
    Textile.textilize(str, do_object_links)
  end
end
