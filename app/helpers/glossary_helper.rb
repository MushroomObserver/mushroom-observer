module GlossaryHelper
  def name_layout(name)
    :term_name.t + ": " + name
  end
  
  def description_layout(description )
    :term_description.t + ": " + description.tpl
  end
  
  def thumbnail_layout(id)
    if id
      thumbnail(id, :border => 0, :votes => false)
    end
  end
end
