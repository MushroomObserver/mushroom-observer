# frozen_string_literal: true

# Base class for form objects used with Superform.
# Provides ActiveModel compatibility and sensible defaults.
class FormObject::Base
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Use demodulized class name for field namespacing.
  # FormObject::AdminSession → "AdminSession" → admin_session[field]
  # Subclasses can override if different namespacing is needed.
  def self.model_name
    ActiveModel::Name.new(self, nil, name.demodulize)
  end
end
