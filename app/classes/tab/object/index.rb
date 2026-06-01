# frozen_string_literal: true

# Polymorphic "List Xs" index link. Replaces
# `Tabs::GeneralHelper#object_index_tab`. Carries the current Query
# through via `q_param`.
class Tab::Object::Index < Tab::Base
  def initialize(object:, q_param: nil, title: nil)
    super()
    @object = object
    @q_param = q_param
    @title_override = title
  end

  def title
    @title_override || :list_objects.t(type: @object.type_tag)
  end

  def path
    args = @object.index_link_args
    return args unless @q_param && args.is_a?(Hash)

    args.merge(q: @q_param)
  end

  def html_options
    { class: "#{@object.type_tag.to_s.pluralize}_index_link" }
  end

  def model
    @object
  end
end
