# frozen_string_literal: true

# "Images" panel used by the comments / namings / suggestions pages
# to show the observation's images vertically as a list (not the
# carousel rendered on the main obs show page — that's
# `Components::Carousel`, rendered directly from
# `observations/show.html.erb`).
#
# Each image gets an `InteractiveImage` plus the copyright notice
# (when the photographer ≠ obs owner) and the image's own notes
# (textilized + truncated to 300 chars).
#
# Replaces `_images.erb`. The `observation_show_image_links`
# helper that built the "reuse images" heading link is inlined as
# a private method here.
class Views::Controllers::Observations::Show::ImagesPanel < Views::Base
  prop :obs, ::Observation
  prop :images, _Array(::Image)
  prop :user, _Nilable(::User), default: nil

  def view_template
    render(Components::Panel.new(
             panel_class: "show_images list-group text-center m-0"
           )) do |panel|
      panel.with_heading { :IMAGES.t }
      panel.with_heading_links { heading_links }
      panel.with_body { render_body }
    end
  end

  private

  # Inlined from `ObservationsHelper#observation_show_image_links`.
  # The "reuse images" link is only meaningful to a user with
  # edit permission on the obs.
  def heading_links
    return unless permission?(@obs)

    render(Components::IconLink.new(
             tab: ::Tab::Observation::ReuseImages.new(observation: @obs)
           ))
  end

  def render_body
    return if @images.none?

    @images.each { |image| render_image_row(image) }
  end

  # Pre-Phlex this was sorted with the thumbnail first; the
  # caller now does the sort (or supplies `images_sorted`).
  def render_image_row(image)
    div(class: "list-group-item") do
      render(Components::Image::Interactive.new(
               user: @user,
               image: image,
               image_link: image.show_link_args.merge(obs: @obs.id),
               original: true,
               is_set: true,
               votes: true
             ))
      render_image_notes(image)
    end
  end

  def render_image_notes(image)
    show_copyright = image.copyright_holder != @obs.user.legal_name
    has_notes = image.notes.present?
    return unless show_copyright || has_notes

    div(class: "text-center") do
      render_copyright(image) if show_copyright
      br if show_copyright && has_notes
      trusted_html(image.notes.tl.truncate_html(300)) if has_notes
    end
  end

  def render_copyright(image)
    render(Components::Image::Copyright.new(
             user: @user, image: image, object: @obs
           ))
  end
end
