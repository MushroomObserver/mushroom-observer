# frozen_string_literal: true

# "Edit external link" link.
class Tab::ExternalLink::Edit < Tab::Base
  def initialize(link:)
    super()
    @link = link
  end

  def title
    :EDIT.l
  end

  def path
    edit_external_link_path(id: @link)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @link
  end
end
