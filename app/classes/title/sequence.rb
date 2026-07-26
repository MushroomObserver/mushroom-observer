# frozen_string_literal: true

# Page heading + browser tab title. The locus is shown in the page
# body ("Locus: …") so the title identifies the sequence by its
# observation instead. Was a zero-arg method on the model
# (`def page_title; ...; end`, aliased for document_title) --
# standardized to accept (and ignore) `user` like every other Title
# subclass, so the object_title.rb consumer doesn't need to
# arity-inspect each model's method to decide whether to pass it.
class Title::Sequence < Title
  def page_title(_user = nil)
    :show_sequence_title.l(id: @object.observation_id)
  end
  alias document_title page_title
end
