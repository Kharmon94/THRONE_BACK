# Seed admin only when we have credentials
email = ENV["ADMIN_SEED_EMAIL"].presence || "admin@throne.local"
password = ENV["ADMIN_SEED_PASSWORD"].presence || "password123"

if User.count.zero? && password.present?
  User.create!(
    email: email,
    password: password,
    password_confirmation: password,
    admin: true
  )
  puts "Created admin user: #{email}"
end
