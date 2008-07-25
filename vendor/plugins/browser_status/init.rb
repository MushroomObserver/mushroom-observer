require 'browser_status'
ActionView::Base.send :include, BrowserStatus
ActionController::Base.send :include, BrowserStatus
