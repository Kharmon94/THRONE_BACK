class Project < ApplicationRecord
  belongs_to :user, optional: true
  has_one_attached :image
  serialize :tags, type: Array, coder: JSON

  validates :title, presence: true
  validates :status, inclusion: { in: %w[published draft] }, allow_nil: true

  scope :published, -> { where(status: "published") }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }

  def image_url
    return nil unless image.attached?
    Rails.application.routes.url_helpers.rails_blob_url(image)
  end
end
