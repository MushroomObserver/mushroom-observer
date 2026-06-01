# frozen_string_literal: true

# "Merge this description into another" icon-link (admin only).
# Caller is responsible for the admin permission check before
# instantiating.
class Tab::Description::Merge < Tab::Base
  def initialize(description:)
    super()
    @description = description
    @type = description.parent.type_tag
  end

  def title
    :show_description_merge.t
  end

  def path
    send(:"new_merge_#{@type}_description_path", @description.id)
  end

  def html_options
    { help: :show_description_merge_help.l, icon: :merge }
  end

  def model
    @description
  end
end
