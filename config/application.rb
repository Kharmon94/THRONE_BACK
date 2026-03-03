require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "active_storage/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module ThroneApi
  class Application < Rails::Application
    config.load_defaults 8.0
    config.api_only = true

    config.generators do |g|
      g.test_framework :test_unit
    end
  end
end
