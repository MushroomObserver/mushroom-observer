# frozen_string_literal: true

# Polymorphic "Cancel and show this object" link — works with any
# object that responds to `#type_tag` (i18n key) and `#show_link_args`
# (the route helper args). Replaces `Tabs::GeneralHelper#object_return_tab`.
class Tab::Object::Return < Tab::Base
  def initialize(object:, title: nil)
    super()
    @object = object
    @title_override = title
  end

  def title
    @title_override || :cancel_and_show.t(type: @object.type_tag)
  end

  def path
    @object.show_link_args
  end

  def html_options
    { class: "#{@object.type_tag}_return_link" }
  end

  def model
    @object
  end
end
