# Be sure to restart your server when you modify this file.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins_list = []
    # Local dev origins are not allowed in production.
    unless Rails.env.production?
      origins_list.concat([
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:4173",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:4173"
      ])
    end
    # FRONTEND_ORIGIN may be a comma-separated list (e.g. apex + www).
    ENV.fetch("FRONTEND_ORIGIN", "").split(",").map { |o| o.strip.chomp("/") }.reject(&:empty?).each do |origin|
      origins_list << origin
    end
    origins(*origins_list.uniq)
    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: ["Authorization"]
  end
end
