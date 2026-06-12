# frozen_string_literal: true

# Action-nav for the image show page. When the image is attached to
# exactly one observation, exposes that observation's show page, the
# Name show page, and a Google Images search for the name. Always
# offers an EOL link (if available), edit / destroy (if the viewer
# can edit), and commercial inquiry (if the image's owner accepts
# such email).
class Tab::Image::ShowActions < Tab::Collection
  def initialize(image:, permission: false)
    super()
    @image = image
    @permission = permission
  end

  private

  def tabs
    [*observation_tabs, eol_tab, *mod_tabs, commercial_tab].compact
  end

  def observation_tabs
    return [] unless @image.observations.length == 1

    obs = @image.observations.first
    [
      Tab::Object::Show.new(object: obs),
      Tab::Object::Show.new(object: obs.name),
      Tab::Image::NameGoogleImages.new(name: obs.name)
    ]
  end

  def eol_tab
    return unless @image.eol_url

    Tab::Image::Eol.new(image: @image)
  end

  def mod_tabs
    return [] unless @permission

    [Tab::Image::Edit.new(image: @image),
     Tab::Image::Destroy.new(image: @image)]
  end

  def commercial_tab
    return unless @image.user.email_general_commercial && !@image.user.no_emails

    Tab::Image::CommercialInquiry.new(image: @image)
  end
end
