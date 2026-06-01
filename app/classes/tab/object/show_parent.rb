# frozen_string_literal: true

# Polymorphic "Show this object's parent" link. Replaces
# `Tabs::GeneralHelper#show_parent_tab`. The object must respond to
# `#parent`, and the parent must respond to `#type_tag` and
# `#show_link_args`.
class Tab::Object::ShowParent < Tab::Base
  def initialize(object:, title: nil)
    super()
    @object = object
    @title_override = title
  end

  def title
    @title_override || :show_object.t(type: @object.parent.type_tag)
  end

  def path
    @object.parent.show_link_args
  end

  def html_options
    { class: "parent_#{@object.parent.type_tag}_link" }
  end

  def model
    @object
  end
end
