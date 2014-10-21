module GlossaryHelper
  def name_layout(name)
    :glossary_term_name.t + ": " + name
  end
  
  def description_layout(description )
    :glossary_term_description.t + ": " + description.tpl
  end
  
  def thumbnail_layout(id)
    if id
      thumbnail(id, :border => 0, :votes => false)
    end
  end
end
