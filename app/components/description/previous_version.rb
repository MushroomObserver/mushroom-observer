# frozen_string_literal: true

# `Version: N <br/>[Previous Version: N-1<br/>]` — current-version
# label, with an optional link to the previous version when one
# exists. Used on every versioned-model show page (name, location,
# description, glossary_term) and inside the description-details
# panel.
#
# Replaces the pre-Phlex `VersionsHelper#show_previous_version` +
# its private `previous_version_link` / `current_version_html`
# composers.
class Components::Description::PreviousVersion < Components::Base
  prop :obj, ::AbstractModel
  prop :versions, _Array(_Interface(:user_id)), default: -> { [] }

  def view_template
    plain("#{:VERSION.t}: #{@obj.version}")
    br
    return unless previous_version && previous_version.version != @obj.version

    a(href: previous_version_path, class: "previous_version_link") do
      plain("#{:show_name_previous_version.t} #{previous_version.version}")
    end
    br
  end

  private

  def previous_version
    @previous_version ||= @versions&.last(2)&.first
  end

  def previous_version_path
    url_for(controller: "#{@obj.show_controller}/versions",
            action: :show, id: @obj.id,
            version: previous_version.version)
  end
end
