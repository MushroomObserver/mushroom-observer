# frozen_string_literal: true

# Polymorphic "List Xs" index link. Replaces
# `Tabs::GeneralHelper#object_index_tab`. Carries the current Query
# through via `index_filter` -- callers must pass a query whose
# model matches `object`'s, since this always links to that model's
# index page (see Query#index_filter).
class Tab::Object::Index < Tab::Base
  def initialize(object:, index_filter: nil, title: nil)
    super()
    @object = object
    @index_filter = index_filter
    @title_override = title
  end

  def title
    @title_override || :list_objects.t(type: @object.type_tag)
  end

  def path
    args = @object.index_link_args
    return args unless @index_filter && args.is_a?(Hash)

    args.merge(@index_filter)
  end

  def html_options
    { class: "#{@object.type_tag.to_s.pluralize}_index_link" }
  end

  def model
    @object
  end
end
