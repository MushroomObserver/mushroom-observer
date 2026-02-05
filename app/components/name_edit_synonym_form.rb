# frozen_string_literal: true

# Form for editing name synonyms.
# Creates its own FormObject internally from the provided kwargs.
#
# @example
#   render(Components::NameEditSynonymForm.new(
#     name: @name,
#     synonym_members: @list_members,
#     deprecate_all: @deprecate_all,
#     current_synonyms: @name.synonyms,
#     proposed_synonyms: @proposed_synonyms
#   ))
#
class Components::NameEditSynonymForm < Components::ApplicationForm
  # rubocop:disable Metrics/ParameterLists
  def initialize(name:, synonym_members: nil, deprecate_all: true,
                 current_synonyms: [], proposed_synonyms: [], new_names: [], **)
    @name = name
    @current_synonyms = current_synonyms
    @proposed_synonyms = proposed_synonyms
    @new_names = new_names

    form_object = FormObject::EditSynonym.new(
      synonym_members: synonym_members,
      deprecate_all: deprecate_all
    )
    super(form_object, **)
  end
  # rubocop:enable Metrics/ParameterLists

  def view_template
    div(class: "row") do
      div(class: "col-sm-6") do
        render_existing_synonyms
        render_proposed_synonyms
      end
      div(class: "col-sm-6") do
        render_members_section
      end
    end

    submit(:name_change_synonyms_submit.l, center: true)
  end

  private

  def render_existing_synonyms
    return unless @current_synonyms.size > 1

    namespace(:existing_synonyms) do |field_namespace|
      div(class: "form-group") do
        div(class: "font-weight-bold my-3") do
          plain("#{:form_synonyms_current_synonyms.l}:")
        end
        help_block(:form_synonyms_current_synonyms_help.t)

        @current_synonyms.each do |n|
          next if n == @name

          render_synonym_checkbox(field_namespace, n)
        end
      end
    end
    hr
  end

  def render_proposed_synonyms
    return if @proposed_synonyms.blank?

    namespace(:proposed_synonyms) do |field_namespace|
      div(class: "form-group") do
        div(class: "font-weight-bold my-3") do
          plain("#{:form_synonyms_proposed_synonyms.l}:")
        end
        help_block(:form_synonyms_proposed_synonyms_help.t)

        @proposed_synonyms.each do |n|
          next if @current_synonyms.include?(n)

          render_synonym_checkbox(field_namespace, n)
        end
      end
    end
  end

  def render_synonym_checkbox(namespace, name_obj)
    render(
      namespace.field(name_obj.id.to_s).checkbox(
        wrapper_options: { label: synonym_checkbox_label(name_obj) },
        value: "1", checked: false
      )
    )
  end

  def synonym_checkbox_label(name_obj)
    link = capture do
      a(href: name_path(name_obj.id)) { trusted_html(name_obj.display_name.t) }
    end
    badge = view_context.show_title_id_badge(name_obj, "")
    [link, badge].safe_join(" ")
  end

  def render_members_section
    render_new_names_alert if @new_names.present?

    checkbox_field(:deprecate_all, label: :form_synonyms_deprecate_synonyms.l)
    help_block(:form_synonyms_deprecate_synonyms_help.t)

    textarea_field(:synonym_members,
                   label: "#{:form_synonyms_names.l}:",
                   data: { autofocus: true }) do |f|
      f.with_between { help_block(members_help) }
    end
  end

  def render_new_names_alert
    render(Components::Alert.new(level: :danger)) do
      div { :form_synonyms_missing_names.l }
      div(class: "pl-3") do
        @new_names.each { |n| div { n } }
      end
      span(class: "help-note mr-3") { :form_synonyms_missing_names_help.t }
    end
  end

  def help_block(text)
    p(class: "help-block") { text }
  end

  def members_help
    :form_synonyms_names_help.t(name: @name.display_name)
  end

  def form_action
    synonyms_of_name_path(@name.id,
                          approved_names: @new_names,
                          approved_synonyms: approved_synonym_ids)
  end

  # Only include synonym IDs when re-rendering with proposed synonyms
  # (after user has confirmed which synonyms to include)
  def approved_synonym_ids
    return [] if @proposed_synonyms.blank?

    (@proposed_synonyms + @current_synonyms).map(&:id).uniq
  end
end
