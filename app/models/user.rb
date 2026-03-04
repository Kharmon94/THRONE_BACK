class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :projects, dependent: :nullify

  def admin?
    admin == true
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    email = conditions.delete(:email)&.to_s&.strip
    return nil if email.blank?
    where("LOWER(email) = LOWER(?)", email).first
  end
end
