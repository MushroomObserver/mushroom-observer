# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  require "arel-helpers"
  include ArelHelpers::ArelTable
  include ArelHelpers::JoinAssociation
end
