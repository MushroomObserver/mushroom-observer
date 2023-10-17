# frozen_string_literal: true

module CupriteHelpers
  # Drop #pause anywhere in a test to stop the execution.
  # Useful when you want to checkout the contents of a web page in the middle
  # of a test running in a headful mode.
  def pause
    page.driver.pause
  end

  # Drop #debug anywhere in a test to open inspector and pause execution
  def debug(*args)
    page.driver.debug(*args)
  end
end
