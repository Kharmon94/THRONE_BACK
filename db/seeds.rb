# Seed admin - create if none exist, or sync when env vars are set
email = (ENV["ADMIN_SEED_EMAIL"].presence || "admin@throne.local").strip
password = (ENV["ADMIN_SEED_PASSWORD"].presence || "password123").strip

if password.blank?
  puts "Skipping admin seed: no password configured"
else
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
