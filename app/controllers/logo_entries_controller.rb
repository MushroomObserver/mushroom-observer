# frozen_string_literal: true

class LogoEntriesController < ApplicationController
  def new
    @logo_entry = LogoEntry.new
  end
end
