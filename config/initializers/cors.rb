# Be sure to restart your server when you modify this file.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins_list = [
      "http://localhost:3000",
      "http://localhost:5173",
      "http://127.0.0.1:3000",
      "http://127.0.0.1:5173"
    ]
    origins_list << ENV["FRONTEND_ORIGIN"] if ENV["FRONTEND_ORIGIN"].present?
    origins(*origins_list.uniq)
    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: ["Authorization"]
  end
end
