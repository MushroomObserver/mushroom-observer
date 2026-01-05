# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap date field component with three selects (year, month, day).
  # Compatible with Rails date_select parameter format.
  #
  # @example
  #   field(:when).date(wrapper_options: { label: "Date:" })
  #
  class DateField < Phlex::HTML
    include Phlex::Rails::Helpers::ClassNames
    include Phlex::Slotable
    include FieldWithHelp
    include FieldLabelRow

    slot :between
    slot :append
    slot :help

    public :between_slot, :append_slot, :help_slot

    attr_reader :field, :attributes, :wrapper_options

    def initialize(field, attributes:, wrapper_options: {})
      super()
      @field = field
      @attributes = attributes
      @wrapper_options = wrapper_options
    end

    def view_template
      render_with_wrapper do
        render_date_selects
      end
    end

    private

    def render_with_wrapper
      label_option = wrapper_options[:label]
      show_label = label_option != false
      label_text = label_option.is_a?(String) ? label_option : default_label
      wrap_class = wrapper_options[:wrap_class]

      div(class: form_group_class(wrap_class)) do
        render_label_row(label_text, false) if show_label
        yield
        render_help_after_field
        render(append_slot) if append_slot
      end
    end

    def default_label
      field.key.to_s.humanize
    end

    def form_group_class(wrap_class)
      classes = "form-group"
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end

    def render_date_selects
      # Wrapper needs ID for JS lookups (matches ERB's date_select_div)
      div(class: "form-inline date-selects", id: field_id) do
        render_day_select
        render_month_select
        render_year_input
      end
    end

    # Year is rendered directly as a text input (not a select).
    # No need for data-controller="year-input" since that controller's purpose
    # is to convert SELECT → INPUT, which we don't need.
    def render_year_input
      input(type: "text",
            name: date_param_name("1i"),
            id: "#{field_id}_1i",
            class: "form-control",
            size: 4,
            value: current_year)
    end

    # Day/month keep data-controller="year-input" for the "connected" marker
    # (the controller sets data-year-input="connected" on all elements it
    # attaches to, but only transforms elements with _1i or _year in their ID).
    def render_month_select
      select(name: date_param_name("2i"), class: "form-control mr-2",
             id: "#{field_id}_2i",
             data: { controller: "year-input" }) do
        month_options.each do |num, name|
          option(value: num, selected: num == current_month) { name }
        end
      end
    end

    def render_day_select
      select(name: date_param_name("3i"), class: "form-control mr-2",
             id: "#{field_id}_3i",
             data: { controller: "year-input" }) do
        day_options.each do |day|
          option(value: day, selected: day == current_day) { day }
        end
      end
    end

    def date_param_name(suffix)
      # Rails expects: observation[when(1i)], observation[when(2i)], etc.
      field.dom.name.sub(/\]$/, "(#{suffix})]").to_s
    end

    def field_id
      field.dom.id
    end

    def current_date
      @current_date ||= field.value || Time.zone.today
    end

    def current_year
      current_date.year
    end

    def current_month
      current_date.month
    end

    def current_day
      current_date.day
    end

    def month_options
      (1..12).map { |m| [m, Date::MONTHNAMES[m]] }
    end

    def day_options
      (1..31).to_a
    end
  end
end
