# frozen_string_literal: true

# One row per excluded iNat user. Callers eager-load `:user`.
module Views::Controllers::Admin::ExcludedInatUsers
  class Table < Views::Base
    INAT_PEOPLE_URL = "#{Inat::Constants::SITE}/people/".freeze

    prop :entries, _Array(::ExcludedInatUser)
    prop :purges, _Hash(String, ::ImagePurge)

    # `render(::Components::Table...)`, not Kit `Table(...)`: this class
    # is itself named Table.
    def view_template
      render(::Components::Table.new(
               @entries, variant: :striped, id: "excluded_inat_users",
                         class: "mt-3"
             )) do |t|
        t.column(:excluded_inat_user_login.l) { |e| render_login(e) }
        t.column(:excluded_inat_user_added_by.l) { |e| render_added(e) }
        t.column(:images.ti) { |e| render_images(e) }
        t.column(:actions.ti) { |e| render_remove(e) }
      end
    end

    private

    def render_login(entry)
      a(href: "#{INAT_PEOPLE_URL}#{entry.inat_login}") { entry.inat_login }
      return unless entry.inat_user_id

      whitespace
      plain("(#{entry.inat_user_id})")
    end

    def render_added(entry)
      plain(entry.user&.login.to_s)
      br
      plain(entry.created_at.web_date)
      return if entry.reason.blank?

      br
      plain(entry.reason)
    end

    def render_images(entry)
      purge = @purges[entry.inat_login]
      if purge && (purge.pending? || purge.running?)
        return plain(:image_purge_progress.l(deleted: purge.deleted_image_count,
                                             count: purge.image_count))
      end

      Button(type: :get, name: :excluded_inat_user_delete_images.l,
             variant: :danger, size: :sm,
             target: new_admin_excluded_inat_user_image_purge_path(entry))
    end

    def render_remove(entry)
      Button(type: :delete, target: admin_excluded_inat_user_path(entry),
             variant: :strip)
    end
  end
end
