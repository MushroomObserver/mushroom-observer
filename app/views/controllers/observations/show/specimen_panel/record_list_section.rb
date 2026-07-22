# frozen_string_literal: true

# Shared shape for the Specimen panel's "list of attached records"
# sections (CollectionNumbersSection, HerbariumRecordsSection):
# a heading ("Collection numbers: [ new ]" / "No collection numbers
# [ new ]"), then either an editable list (edit/remove links), a
# readonly list (show-link only), or nothing (no records, no
# permission to add). Subclasses supply only what genuinely differs.
class Views::Controllers::Observations::Show::SpecimenPanel
  class RecordListSection < Views::Base
    prop :obs, ::Observation
    prop :user, _Nilable(::User), default: nil
    prop :has_sibling_records, _Boolean, default: false

    # Subclasses set this via `self.model_class = ...` at the top of
    # their class body -- class-level identity (which subclass this
    # is), not per-instance data, so `class_attribute` rather than
    # `prop`. See the record-list-section design discussion (PR
    # description / commit) for why a `prop` would be the wrong fit.
    class_attribute :model_class

    def view_template
      div(id: dom_id,
          data: { controller: "section-update",
                  section_update_user_value: @user&.id }) do
        render_body
      end
    end

    private

    def render_body
      records = @obs.public_send(plural_tag)
      plain(heading(records))
      if records.any? && can_edit?
        render_new_link
        render_editable_rows(records)
      elsif records.any?
        render_readonly_rows(records)
      elsif can_edit?
        render_new_link
      end
    end

    # ---- derived from model_class -- no per-subclass override needed ----

    def type_tag
      model_class.name.underscore.to_sym
    end

    def plural_tag
      type_tag.to_s.pluralize.to_sym
    end

    def dom_id
      "observation_#{plural_tag}"
    end

    def show_tab_class
      "Tab::#{model_class.name}::Show".constantize
    end

    def new_tab_class
      "Tab::#{model_class.name}::New".constantize
    end

    def heading(records)
      if records.any? || @has_sibling_records
        "#{append_colon(plural_tag.ti)} "
      else
        "#{:no_objects.t(type: type_tag)} "
      end
    end

    def can_edit?
      in_admin_mode? || @obs.can_edit?(@user)
    end

    def render_show_link(record)
      content, path, opts = show_tab_class.new(
        type_tag => record, observation: @obs
      ).to_a
      a(href: url_for(path), **opts) { trusted_html(content) }
    end

    def render_new_link
      InlineCRUDLinks(modal_id: type_tag.to_s,
                      tab: new_tab_class.new(observation: @obs))
    end

    def render_editable_rows(records)
      ul(class: "tight-list") { records.each { |r| render_editable_row(r) } }
    end

    def render_editable_row(record)
      li(id: "#{type_tag}_#{record.id}") do
        render_show_link(record)
        InlineCRUDLinks(target: record, observation: @obs, user: @user)
        render_editable_extra_content(record)
      end
    end

    def render_readonly_rows(records)
      ul(class: "tight-list") { records.each { |r| render_readonly_row(r) } }
    end

    def render_readonly_row(record)
      li(id: "#{type_tag}_#{record.id}") do
        render_show_link(record)
        render_readonly_extra_content(record)
      end
    end

    # ---- optional hooks, default no-op; HerbariumRecordsSection
    # overrides both with its MCP-search-link presentation, which
    # deliberately differs between the two contexts (indented icon-only
    # link in the editable row vs. herbarium-code-prefixed link in the
    # readonly row) ----

    def render_editable_extra_content(_record) = nil
    def render_readonly_extra_content(_record) = nil
  end
end
