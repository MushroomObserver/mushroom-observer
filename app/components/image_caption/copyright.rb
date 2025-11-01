# frozen_string_literal: true

# Component for displaying image copyright information.
#
# @example Basic usage
#   render Components::ImageCaption::Copyright.new(
#     user: current_user,
#     image: @image
#   )
#
# @example With context object
#   render Components::ImageCaption::Copyright.new(
#     user: current_user,
#     image: @image,
#     object: @observation
#   )
class Components::ImageCaption::Copyright < Components::Base
  include ApplicationHelper

  prop :user, _Nilable(User)
  prop :image, _Nilable(::Image)
  prop :object, _Nilable(Object), default: nil

  def view_template
    return "" unless @image && show_copyright?

    holder = if @image.copyright_holder == @image.user.legal_name
               user_link(@image.user)
             else
               @image.copyright_holder.to_s.t
             end

    div(class: "image-copyright small") do
      @image.license&.copyright_text(@image.year, holder)
    end
  end

  private

  def show_copyright?
    obj = @object || @image
    obj.type_tag != :observation ||
      (obj.type_tag == :observation &&
       @image.copyright_holder != obj.user&.legal_name)
  end
end
