# frozen_string_literal: true

# Herbarium-records section of the Specimen panel -- same shape as
# CollectionNumbersSection (via RecordListSection), plus an extra
# permission path (curated herbaria) and a "search MCP" link for
# records whose herbarium is `web_searchable?`.
class Views::Controllers::Observations::Show::SpecimenPanel
  class HerbariumRecordsSection < RecordListSection
    self.model_class = ::HerbariumRecord

    private

    # Editable when admin, obs owner, or any curated herbarium.
    def can_edit?
      super || @user&.curated_herbaria&.any?
    end

    # Editable row: indented icon-only link below the show-link.
    def render_editable_extra_content(record)
      return unless record.herbarium.web_searchable?

      br
      span(class: "indent") do
        Link(type: :external,
             content: :herbarium_record_collection.t,
             path: record.herbarium.mcp_url(record.accession_number))
      end
    end

    # Readonly row: same link, prefixed with the herbarium's code, no
    # indent wrapper -- deliberately different presentation from the
    # editable row (not a bug, kept as-is during the RecordListSection
    # unification).
    def render_readonly_extra_content(record)
      return unless record.herbarium.web_searchable?

      br
      Link(type: :external,
           content: "#{record.herbarium.code} " \
                    "#{:herbarium_record_collection.t}",
           path: record.herbarium.mcp_url(record.accession_number))
    end
  end
end
