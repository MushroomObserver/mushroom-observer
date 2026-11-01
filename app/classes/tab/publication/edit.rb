# frozen_string_literal: true

# "Edit this publication" icon-link, used by Components::InlineCRUDLinks
# on the publications index's admin column. Caller is responsible for
# the edit-permission check (`publication.can_edit?(user)` or admin
# mode) before instantiating.
class Tab::Publication::Edit < Tab::Base
  def initialize(publication:)
    super()
    @publication = publication
  end

  def title
    :edit_object.t(type: Publication)
  end

  def path
    edit_publication_path(@publication.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @publication
  end
end
