# frozen_string_literal: true

# Mix into any `acts_as_versioned` model whose version table has a
# `user_id` column, to attribute each version to whoever's editing —
# via an explicit per-instance accessor, not the deprecated
# `User.current` thread-local. Used by Name, NameDescription, Location,
# LocationDescription, and GlossaryTerm.
#
# A host that needs extra bookkeeping alongside plain attribution
# (e.g. Name's UserStats "first version by this user" contribution
# point - see Name::Resolve#new_version_for_user?/
# #award_version_contribution) computes whatever depends on the OLD
# user_id value before calling save, since this module's after_save
# hook overwrites it immediately once the version row exists.
#
# `versioned_class`'s own `before_save` can't reach the specific host
# instance being saved — its `belongs_to` association re-queries from
# the DB, missing this instance's in-memory `current_user` — so the
# fix-up happens `after_save` on the host instead, once the version
# row already exists.
module VersionedByCurrentUser
  extend ActiveSupport::Concern

  included do
    attr_accessor :current_user

    after_save :set_version_current_user
  end

  def set_version_current_user
    return unless saved_version_changes?

    ver = self.class.versioned_class.where(
      self.class.versioned_foreign_key => id
    ).last
    ver&.update_column(:user_id, current_user&.id)
  end
end
