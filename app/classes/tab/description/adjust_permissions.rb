# frozen_string_literal: true

# "Adjust description permissions" icon-link. Only applies to
# NameDescriptions (LocationDescriptions don't have per-user
# permissions). Caller is responsible for the admin permission
# check before instantiating.
class Tab::Description::AdjustPermissions < Tab::Base
  def initialize(description:)
    super()
    @description = description
  end

  def title
    :show_description_adjust_permissions.t
  end

  def path
    edit_permissions_name_description_path(@description.id)
  end

  def html_options
    { confirm: :show_description_adjust_permissions_help.l, icon: :adjust }
  end

  def model
    @description
  end
end
