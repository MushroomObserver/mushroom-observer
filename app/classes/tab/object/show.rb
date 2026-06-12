# frozen_string_literal: true

# Polymorphic "Show this object" link. Replaces
# `Tabs::GeneralHelper#show_object_tab`.
class Tab::Object::Show < Tab::Base
  def initialize(object:, title: nil)
    super()
    @object = object
    @title_override = title
  end

  def title
    @title_override || :show_object.t(type: @object.type_tag)
  end

  def path
    @object.show_link_args
  end

  def html_options
    { class: "#{@object.type_tag}_link" }
  end

  def model
    @object
  end
end
