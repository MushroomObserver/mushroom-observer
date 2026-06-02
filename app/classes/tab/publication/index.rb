# frozen_string_literal: true

# "Publications index" link.
class Tab::Publication::Index < Tab::Base
  def title
    :publication_index.t
  end

  def path
    publications_path
  end
end
