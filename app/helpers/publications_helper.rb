# frozen_string_literal: true

# Helper methods for publications views
module PublicationsHelper
  def publication_form_action(publication, action)
    case action
    when :create
      publications_path
    when :update
      publication_path(publication)
    end
  end
end
