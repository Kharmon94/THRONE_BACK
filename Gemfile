source "https://rubygems.org"

ruby "3.3.0"

gem "rails", "8.0.4"

gem "bootsnap", require: false
gem "puma", ">= 5.0"
gem "rack-cors"

gem "devise"
gem "jwt"
gem "cancancan"
gem "aws-sdk-s3", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "sqlite3"
end

group :production do
  gem "pg"
end
