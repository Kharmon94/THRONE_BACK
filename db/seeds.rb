# Create admin user if none exists
if User.count.zero?
  User.create!(
    email: "admin@throne.local",
    password: "password123",
    password_confirmation: "password123",
    admin: true
  )
  puts "Created default admin user: admin@throne.local / password123"
end
