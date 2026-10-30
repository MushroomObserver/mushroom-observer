# frozen_string_literal: true

# The foot of the profile edit page: the controls that limit how the
# user's images are used (#5521). Stopping future imports and deleting
# what is already here are separate controls; neither triggers the other.
module Views::Controllers::Account::Profile
  class Edit::DangerZone < Views::Base
    prop :user, ::User
    prop :purge, _Nilable(::ContentPurge)

    def view_template
      Panel(panel_class: "panel-danger mt-4",
            panel_id: "profile_danger_zone") do |panel|
        panel.with_heading { strong { plain(:profile_danger_zone.l) } }
        panel.with_body do
          p { plain(:profile_danger_zone_intro.l) }
          render_imports
          render_delete
        end
      end
    end

    private

    def render_imports
      h4(class: "mt-4") { plain(:profile_inat_imports.l) }
      return render_link_inat if @user.inat_username.blank?

      p { plain(:profile_inat_linked.l(login: @user.inat_username)) }
      render(Edit::InatOptOutForm.new(@user))
    end

    def render_link_inat
      p { plain(:profile_inat_link_help.l) }
      Button(type: :get, name: :profile_inat_link.l,
             target: new_account_inat_link_path)
    end

    def render_delete
      h4(class: "mt-4") { plain(:profile_delete_content.l) }
      return render_purge_status if @purge

      p { plain(:profile_delete_content_help.l) }
      Button(type: :get, name: :profile_delete_content_button.l,
             target: new_account_content_purge_path, variant: :danger)
    end

    def render_purge_status
      p(id: "profile_content_purge_status") do
        plain(:profile_content_purge_running.l(
                deleted: @purge.deleted_image_count,
                count: @purge.image_count
              ))
      end
    end
  end
end
