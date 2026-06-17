# frozen_string_literal: true

# Past-versions table shown on every `versions#show` page (name,
# location, description, glossary term). Three columns per row —
# updated date / editor / version-link — emitted via
# `Components::Table` in column mode.
#
# Inlines the entire `VersionsHelper#build_version_table` chain
# (`find_version_date`, `find_version_user`, `link_to_version`,
# `initial_version_link_text`). With that chain gone, the helper
# file is empty and is deleted in the same commit.
module Views::Controllers::Versions
  class Table < Views::Base
    prop :obj, ::AbstractModel
    prop :versions, _Array(_Interface(:user_id))
    # Optional `args[:bold]` callable — only the name-version page
    # uses it to embolden the row of a specific version (the
    # non-deprecated one).
    prop :args, _Hash(Symbol, _Any?), default: -> { {} }

    def view_template
      render(Components::Panel.new(
               panel_id: "#{@obj.type_tag}_versions"
             )) do |panel|
        panel.with_heading { :VERSIONS.l }
        panel.with_body { render_table }
      end
    end

    private

    def render_table
      render(Components::Table.new(
               @versions.reverse,
               show_headers: false,
               class: "table-hover mb-0"
             )) do |t|
        t.column("") { |ver| render_date_cell(ver) }
        t.column("") { |ver| render_user_cell(ver) }
        t.column("") { |ver| render_link_cell(ver) }
      end
    end

    def render_date_cell(ver)
      plain(ver.updated_at.web_date)
    rescue StandardError
      plain(:unknown.t)
    end

    def render_user_cell(ver)
      user = ::User.safe_find(ver.user_id)
      return plain(:unknown.t) unless user

      render(::Components::UserLink.new(user: user, name: user.login))
    end

    def render_link_cell(ver)
      if ver == @versions.last
        a(href: url_for(@obj.show_link_args),
          class: "latest_version_link") do
          emit_version_link_text(ver)
        end
      else
        a(href: url_for(controller: "#{@obj.show_controller}/versions",
                        action: :show, id: @obj.id,
                        version: ver.version),
          class: "initial_version_link") do
          emit_version_link_text(ver)
        end
      end
    end

    def emit_version_link_text(ver)
      label = "#{:VERSION.t} #{ver.version}"
      if @args[:bold]&.call(ver)
        strong { plain(label) }
      else
        plain(label)
      end
      return unless ver.respond_to?(:display_name)

      br
      trusted_html(ver.display_name.t)
    end
  end
end
