# frozen_string_literal: true

# Keep personal data and secrets out of request logs (Railway keeps app and HTTP
# logs for 90 days). Partial, case-insensitive matches: "email" also covers
# "user[email]", "token" covers "reschedule_token", etc. This also filters the
# query string in Rails' "Started ..." log line (request.filtered_path).
Rails.application.config.filter_parameters += %i[
  passw email token secret _key crypt salt certificate otp ssn cvv cvc
  name company notes phone website
]
