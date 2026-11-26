# frozen_string_literal: true

# Bound form for "attach an existing image by ID" on the image reuse
# index. One `img_id` field. The "include other users' images" toggle
# renders directly on `Index` (into the pagination row's sorter slot,
# before `Index`'s `add_pagination` call); the surrounding image
# grid is also `Index`'s concern, and POSTs directly via
# per-thumbnail links (`Components::InteractiveImage`).
#
# The `target` is the domain object whose images are being chosen for
# — `Observation`, `User` (profile), or `GlossaryTerm`. Reusing an
# image is a RESTful member action on the image itself
# (`POST /images/:id/reuse`, see config/routes.rb), with `target_type`/
# `target_id` carried as query params -- but unlike a per-thumbnail
# link, this form doesn't know which image id it's submitting until
# the user types one into the field. `PLACEHOLDER_ID` stands in for
# that id in the rendered `action=`; the `id-sanitizer` Stimulus
# controller rewrites it to the typed value (rejecting anything that
# isn't a plain positive integer) just before submit.
module Views::Controllers::Images::Reuse
  class Index::Form < Components::ApplicationForm
    PLACEHOLDER_ID = "__ID__"

    prop :target, _Union(::Observation, ::User, ::GlossaryTerm)

    def initialize(**)
      super(FormObject::ImageReuse.new, **)
    end

    def form_action
      self.class.attach_path_for(PLACEHOLDER_ID, @target)
    end

    def self.attach_path_for(image_id, target, **extra_params)
      Rails.application.routes.url_helpers.reuse_image_path(
        image_id, target_type: target.class.name, target_id: target.id,
                  **extra_params
      )
    end

    def self.reuse_path_for(target, **extra_params)
      Rails.application.routes.url_helpers.images_reuse_path(
        target_type: target.class.name, target_id: target.id, **extra_params
      )
    end

    def around_template
      @attributes[:data] ||= {}
      @attributes[:data][:controller] = "id-sanitizer"
      @attributes[:data][:id_sanitizer_placeholder_value] = PLACEHOLDER_ID
      @attributes[:data][:action] = "submit->id-sanitizer#submit"
      super
    end

    def view_template
      Row do
        Column(md: 6) do
          ContentPadded { trusted_html(:image_reuse_id_help.tp) }
        end
        Column(md: 6) { render_id_field_row }
      end
    end

    private

    def render_id_field_row
      div(class: "form-group form-inline mt-3") do
        text_field(:img_id, label: :image_reuse_id,
                            inline: true, size: 8, wrap_class: "mb-0",
                            data: { autofocus: "true",
                                    id_sanitizer_target: "input" })
        submit(:image_reuse_reuse.l, as: :button,
                                     name: "commit", class: "ml-3")
      end
    end
  end
end
