# frozen_string_literal: true

module Components
  # Bootstrap alert component
  #
  # @example Basic usage
  #   render(Components::Alert.new(message: "Success!", level: :success))
  #
  # @example With block
  #   render(Components::Alert.new(level: :warning)) do
  #     plain "Warning: "
  #     strong "Be careful!"
  #   end
  #
  # @example With custom attributes
  #   render(Components::Alert.new(
  #     message: "Info message",
  #     level: :info,
  #     id: "my-alert",
  #     class: "my-custom-class"
  #   ))
  class Alert < Base
    prop :message, String, default: ""
    prop :level, _Union(:success, :info, :warning, :danger), default: :warning
    prop :attributes, _Hash(Symbol, _Any), :**

    def view_template
      div(**alert_attributes) do
        if @message.present?
          plain(@message)
        elsif block_given?
          yield
        end
      end
    end

    private

    def alert_attributes
      {
        class: alert_classes,
        **@attributes.except(:class)
      }
    end

    def alert_classes
      classes = ["alert", "alert-#{@level}"]
      classes << @attributes[:class] if @attributes[:class]
      classes.compact.join(" ")
    end
  end
end
