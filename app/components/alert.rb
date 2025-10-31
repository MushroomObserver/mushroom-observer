# frozen_string_literal: true

module Components
  # Bootstrap alert component
  #
  # @example Basic usage
  #   render Components::Alert.new("Success!", level: :success)
  #
  # @example With block
  #   render Components::Alert.new(level: :warning) do
  #     plain "Warning: "
  #     strong "Be careful!"
  #   end
  #
  # @example With custom attributes
  #   render Components::Alert.new(
  #     "Info message",
  #     level: :info,
  #     id: "my-alert",
  #     class: "my-custom-class"
  #   )
  class Alert < Base
    # @param message [String, nil] The alert message (optional if using block)
    # @param level [Symbol] The Bootstrap alert level (:success, :info, :warning, :danger)
    # @param attributes [Hash] Additional HTML attributes (id, class, data, etc.)
    def initialize(message = nil, level: :warning, **attributes)
      @message = message
      @level = level
      @attributes = attributes
      super()
    end

    def view_template(&)
      div(**alert_attributes) do
        if @message
          plain @message
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
