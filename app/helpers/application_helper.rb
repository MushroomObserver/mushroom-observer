# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def lnbsp(key)
    key.l.gsub(' ', '&nbsp;')
  end
end
