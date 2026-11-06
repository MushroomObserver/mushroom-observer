# frozen_string_literal: true

# Component for displaying image copyright information.
#
# @example Basic usage
#   ImageFragment(type: :copyright, user: @user, image: @image)
#
# @example With context object
#   ImageFragment(type: :copyright, user: @user, image: @image,
#                 object: @observation)
class Components::ImageFragment::Copyright < Components::Base
  prop :user, _Nilable(::User)
  prop :image, _Nilable(::Image)
  prop :object, _Nilable(::AbstractModel), default: nil

  def view_template
    return "" unless @image && show_copyright?

    div(class: "image-copyright small") { render_copyright_text }
  end

  # A class method, not private view_template logic, since
  # `images/show/license_history_panel.rb` needs the same text for
  # historical license/holder combos that don't necessarily match
  # the current @image.
  # rubocop:disable Style/StringConcatenation -- `+` (not
  # interpolation) is load-bearing: chaining off a SafeBuffer
  # HTML-escapes `name` (untrusted DB text) while leaving the
  # trusted tag/entity fragments alone. Autocorrect would flatten
  # this to interpolation and drop the escaping.
  def self.text_for(license:, year:, name:)
    safe = ActiveSupport::SafeBuffer.new("")
    if license.url.match?(%r{/(publicdomain|cc0)/?})
      safe + :image_show_public_domain.t + " " + name
    else
      safe + :image_show_copyright.t +
        ActiveSupport::SafeBuffer.new(" &copy; ") + "#{year} " + name
    end
  end
  # rubocop:enable Style/StringConcatenation

  private

  def render_copyright_text
    return unless @image.license

    self.class.text_for(license: @image.license, year: @image.year,
                        name: copyright_holder_name)
  end

  def copyright_holder_name
    if @image.copyright_holder == @image.user.legal_name
      capture { Link(type: :user, user: @image.user) }
    else
      @image.copyright_holder.to_s.t
    end
  end

  def show_copyright?
    obj = @object || @image
    obj.type_tag != :observation ||
      (obj.type_tag == :observation &&
       @image.copyright_holder != obj.user&.legal_name)
  end
end
