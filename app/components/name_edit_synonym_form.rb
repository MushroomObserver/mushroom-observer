# frozen_string_literal: true

# Form for editing name synonyms
#
# @example
#   render(Components::NameEditSynonymForm.new(
#     FormObject::EditSynonym.new(synonym_members: @list_members),
#     name: @name,
#     context: { ... }
#   ))
#
class Components::NameEditSynonymForm < Components::ApplicationForm
  include Phlex::Rails::Helpers::LinkTo

  def initialize(model, name:, context: {}, **)
    @name = name
    @current_synonyms = context[:current_synonyms] || []
    @proposed_synonyms = context[:proposed_synonyms] || []
    @new_names = context[:new_names] || []
    @list_members = context[:list_members]
    @deprecate_all = context[:deprecate_all]
    super(model, **)
  end

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
    [
      link_to(name_obj.display_name.t, name_path(name_obj.id)),
      "(#{name_obj.id})"
    ].safe_join(" ")
  end

  def render_members_section
    render_new_names_alert if @new_names.present?

    checkbox_field(:deprecate_all, label: :form_synonyms_deprecate_synonyms.l)
    help_block(:form_synonyms_deprecate_synonyms_help.t)

    textarea_field(:synonym_members,
                   label: "#{:form_synonyms_names.l}:",
                   value: @list_members,
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
