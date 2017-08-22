# Superclass for all app models
# This gives apps a single spot to configure app-wide model behavior.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
