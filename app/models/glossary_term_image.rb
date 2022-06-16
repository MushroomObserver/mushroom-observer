# frozen_string_literal: true

# Glue table between glossary terms and images.
class GlossaryTermImage < ApplicationRecord
  belongs_to :glossary_term
  belongs_to :image

  # default_scope -> { order("image.vote_cache DESC") }
end
