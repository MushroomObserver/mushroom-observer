# frozen_string_literal: true

# "Occurrence of [name]" -- every member observation shares one
# consensus naming (Observation::NamingConsensus pools votes across
# occurrence siblings), read off the primary observation.
class Title::Occurrence < Title
  def page_title(_user = nil)
    name = @object.primary_observation&.name
    return super unless name

    :show_occurrence_title.t(name: name.display_name).small_author
  end

  def document_title
    @object.primary_observation&.name&.text_name || super
  end
end
