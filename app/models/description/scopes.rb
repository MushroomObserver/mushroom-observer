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
    # LocationDescription. Covers both the join tables
    # (`<prefix>_admins`, `_authors`, `_editors`, `_readers`,
    # `_writers`) and their through associations
    # (`admin_groups`, `authors`, `editors`, `reader_groups`,
    # `writer_groups`).
    #
    # The admin/reader/writer join records belong_to `:user_group`
    # (preloaded for `update_groups` in the permissions concern); the
    # author/editor join records belong_to `:user`. The
    # admin/reader/writer through groups are preloaded for their names /
    # `include?(all_users)` checks, but their `users` are NOT: only the
    # permissions form reads group `users`, lazily and only on small groups
    # (`group.users.first` on personal groups, `group.users.include?(user)`
    # on named project groups). The `all_users` group is always skipped or
    # rendered by name, never enumerated. Preloading group `users` would
    # materialize the entire ~90k-member `all_users` group on every public
    # description show page — a multi-second render + OOM. The permissions
    # form uses the non-strict `permissions_includes` and lazy-loads instead.
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
