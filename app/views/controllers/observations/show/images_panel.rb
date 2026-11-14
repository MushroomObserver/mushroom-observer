# frozen_string_literal: true

# "Images" panel used by the comments / namings / suggestions pages
# to show the observation's images vertically as a list (not the
# carousel rendered on the main obs show page — that's
# `Components::ImageGallery`, rendered directly from
# `observations/show.rb`).
#
# Each image gets an `InteractiveImage` plus the copyright notice
# (when the photographer ≠ obs owner) and the image's notes
# (textilized + truncated to 300 chars).
class Views::Controllers::Observations::Show::ImagesPanel < Views::Base
  prop :obs, ::Observation
  prop :images, _Array(::Image)
  prop :user, _Nilable(::User), default: nil

  def view_template
    Panel(class: "show_images m-0") do |panel|
      panel.with_heading { :images.ti }
      panel.with_heading_links { heading_links }
      panel.with_body(wrapper: false) { render_body }
    end
  end

  private

  # The "reuse images" link is only meaningful to a user with
  # edit permission on the obs.
  def heading_links
    return unless permission?(@obs)

    Link(type: :get,
         tab: ::Tab::Observation::ReuseImages.new(observation: @obs))
  end

  def render_body
    return if @images.none?

    ListGroup(flush: true, class: "text-center") do |list|
      @images.each { |image| list.item { render_image_content(image) } }
    end
  end

  # Pre-Phlex this was sorted with the thumbnail first; the
  # caller now does the sort (or supplies `images_sorted`).
  def render_image_content(image)
    InteractiveImage(
      user: @user,
      image: image,
      image_link: image.show_link_args.merge(obs: @obs.id),
      original: true,
      is_set: true,
      votes: true
    )
    render_image_notes(image)
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
    ImageFragment(type: :copyright, user: @user, image: image, object: @obs)
  end
end
