# frozen_string_literal: true

module Description::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do
    scope :is_default, lambda {
      joins(:name).where(parent_class[:description_id].not_eq(nil)).distinct
    }
    scope :is_not_default, lambda {
      joins(:name).where(parent_class[:description_id].eq(nil)).distinct
    }
    # scope searching notes content all fields, using a SearchParams phrase
    scope :content_has,
          ->(phrase) { search_columns(searchable_columns, phrase) }
    # alias used by advanced_search
    scope :search_content,
          ->(phrase) { content_has(phrase) }
  end

  module ClassMethods
    # class methods here, `self` included
    def parent_class
      parent_type.camelize.constantize
    end

    # Preload subtree used by `show_includes` in NameDescription /
    # LocationDescription: the join tables plus their through
    # associations (`admin_groups`, `authors`, `editors`,
    # `reader_groups`, `writer_groups`).
    #
    # Group `users` are deliberately NOT preloaded here: that would
    # materialize the entire ~90k-member `all_users` group on every
    # public description show page -- a multi-second render + OOM.
    # Only the permissions form reads group `users`, lazily and on
    # small groups, via the non-strict `permissions_includes`.
    def permissions_subtree
      prefix = name.underscore # "name_description" / "location_description"
      [
        :admin_groups,
        :authors,
        :editors,
        :reader_groups,
        :writer_groups,
        { "#{prefix}_admins": :user_group },
        { "#{prefix}_authors": :user },
        { "#{prefix}_editors": :user },
        { "#{prefix}_readers": :user_group },
        { "#{prefix}_writers": :user_group }
      ]
    end
  end
end
