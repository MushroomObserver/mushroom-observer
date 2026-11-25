# frozen_string_literal: true

# "Reuse an existing image" action link on the glossary term show page.
class Tab::GlossaryTerm::ReuseImages < Tab::Base
  def initialize(term:)
    super()
    @term = term
  end

  def title
    :show_glossary_term_reuse_image.t
  end

  def path
    images_reuse_path(target_type: "GlossaryTerm", target_id: @term.id)
  end

  def html_options
    { icon: :reuse }
  end

  def model
    @term
  end
end
