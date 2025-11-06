# frozen_string_literal: true

# Component for displaying image information including copyright, original
# name, and notes.
#
# Can render complete image info or just copyright fragment.
#
# @example Full image info
#   render Components::ImageInfo.new(
#     user: current_user,
#     image: @image,
#     object: @observation,
#     original: true
#   )
#
# @example Just copyright
#   render Components::ImageInfo.new(
#     user: current_user,
#     image: @image
#   ).copyright
class Components::ImageInfo < Components::Base
  prop :user, _Nilable(User)
  prop :image, _Nilable(::Image)
  prop :object, _Nilable(Object), default: nil
  prop :original, _Boolean, default: false

  def view_template
    return "" unless @image

    [
      owner_original_name,
      copyright,
      notes
    ].compact_blank.safe_join
  end

  # Render copyright using ImageCopyright component
  def copyright
    return "" unless @image

    render(Components::ImageCopyright.new(
             user: @user,
             image: @image,
             object: @object
           ))
  end

  private

  def owner_original_name
    return "" unless show_original_name? && (owner_name = @image.original_name)

    div(class: "image-original-name") { owner_name }
  end

  def show_original_name?
    @original && @image &&
      @image.original_name.present? &&
      (permission?(@image) ||
       @image.user &&
       @image.user.keep_filenames == "keep_and_show")
  end

  def notes
    return "" if @image.notes.blank?

    div(class: "image-notes") { @image.notes.tl.truncate_html(300) }
  end
end
