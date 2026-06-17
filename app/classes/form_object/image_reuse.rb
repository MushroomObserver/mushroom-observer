# frozen_string_literal: true

# Backs `Components::Image::ReuseForm` — the small one-field form
# that lets a viewer attach an existing image to an observation,
# user profile, or glossary term by its numeric ID. The form's
# only field is `img_id`; the surrounding image matrix
# (`Components::MatrixTable` of clickable thumbnails) submits to
# the same controller action via a bare URL param, so the receiving
# action reads both the namespaced FormObject param and the raw
# `params[:img_id]` from the matrix click.
class FormObject::ImageReuse < FormObject::Base
  attribute :img_id, :integer
end
