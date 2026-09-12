# Seed admin - create if none exist, or sync when env vars are set
email = (ENV["ADMIN_SEED_EMAIL"].presence || "admin@throne.local").strip
password = ENV["ADMIN_SEED_PASSWORD"].to_s.strip

if Rails.env.production? && password.blank?
  puts "Skipping admin seed in production: set ADMIN_SEED_PASSWORD"
elsif password.blank?
  password = "password123"
  puts "WARNING: Using default admin password for #{Rails.env}. Set ADMIN_SEED_PASSWORD."
end

if password.present?
  admin = User.find_by("LOWER(email) = LOWER(?)", email)
  if admin
    admin.update!(password: password, password_confirmation: password, admin: true)
    puts "Updated admin user: #{admin.email}"
  else
    User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      admin: true
    )
    puts "Created admin user: #{email}"
  end
end
