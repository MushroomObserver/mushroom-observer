# frozen_string_literal: true

module Views::Controllers::Translations
  # Old-versions panel for the translations edit UI. Reloadable
  # standalone — the controller's `update` action targets
  # `#translation_versions` via turbo-stream.
  class Versions < Views::Base
    prop :edit_tags, _Array(::String), default: -> { [] }
    prop :translated_records,
         _Hash(::String, ::TranslationString), default: -> { {} }
    prop :user, ::User
    # `{ user_id => login }` — pre-computed in the controller so the
    # view doesn't run AR queries to resolve old-version authors.
    prop :user_logins, _Hash(::Integer, ::String), default: -> { {} }

    def view_template
      div(id: "translation_versions") do
        @resolved_logins = @user_logins.merge(@user.id => @user.login)
        @done_header = false
        @edit_tags.each { |ttag| render_tag_versions(ttag) }
      end
    end

    private

    def render_tag_versions(ttag)
      record = @translated_records[ttag]
      return unless record

      versions_to_show = nontrivial_versions(record)
      return if versions_to_show.empty?

      render_header_once
      h5(class: "underline mb-1") { "#{ttag}:" }
      render_versions_table(versions_to_show)
    end

    def nontrivial_versions(record)
      last_text = record.text
      record.versions.reverse.each_with_object([]) do |version, acc|
        next if version.text == last_text

        acc << version
        last_text = version.text
      end
    end

    def render_header_once
      return if @done_header

      hr(class: "my-5")
      h4(class: "mb-4 font-weight-bold") do
        "#{:edit_translations_old_versions.l}:"
      end
      @done_header = true
    end

    def render_versions_table(versions)
      Table(versions,
            variant: :striped,
            class: "old_versions",
            show_headers: false) do |t|
        t.column(nil) { |v| render_user_cell(v.user_id) }
        t.column(nil) { |v| plain(v.updated_at.web_date) }
        t.column(nil) { |v| p { plain(v.text) } }
      end
    end

    def render_user_cell(user_id)
      login = @resolved_logins[user_id].to_s
      if login.blank?
        plain("--")
      else
        Link(type: :user, user: user_id, name: login)
      end
    end
  end
end
