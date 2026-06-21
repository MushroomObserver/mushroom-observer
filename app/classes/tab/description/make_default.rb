# frozen_string_literal: true

# "Make this description the default for the parent" PUT-button
# tab. Caller is responsible for the conditional checks (user
# logged-in, description public, not already the default) before
# instantiating.
class Tab::Description::MakeDefault < Tab::Base
  def initialize(description:)
    super()
    @description = description
    @type = description.parent.type_tag
  end

  def title
    :show_description_make_default.t
  end

  def path
    send(:"make_default_#{@type}_description_path", @description.id)
  end

  def html_options
    { button: :put, help: :show_description_make_default_help.l,
      icon: :make_default }
  end

  def model
    @description
  end
end
