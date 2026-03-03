# Be sure to restart your server when you modify this file.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins_list = ["localhost:3000", "localhost:5173", "127.0.0.1:3000", "127.0.0.1:5173"]
    origins_list << ENV["FRONTEND_ORIGIN"] if ENV["FRONTEND_ORIGIN"].present?
    origins(*origins_list)
    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: ["Authorization"]
  end
end
