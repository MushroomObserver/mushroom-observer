# frozen_string_literal: true

module Components
  # Bootstrap alert component
  #
  # @example Basic usage
  #   Alert(message: "Success!", level: :success)
  #
  # @example With block
  #   Alert(level: :warning) do
  #     plain "Warning: "
  #     strong "Be careful!"
  #   end
  #
  # @example With custom attributes
  #   Alert(
  #     message: "Info message",
  #     level: :info,
  #     id: "my-alert",
  #     class: "my-custom-class"
  #   )
  class Alert < Base
    prop :message, String, default: ""
    prop :level, _Union(:success, :info, :warning, :danger), default: :warning
    prop :attributes, _Hash(Symbol, _Any), :**

    def view_template
      div(**mix({ class: "alert alert-#{@level}" }, @attributes)) do
        if @message.present?
          plain(@message)
        elsif block_given?
          yield
        end
      end
    end
  end
end
