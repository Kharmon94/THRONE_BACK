class Project < ApplicationRecord
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  MAX_IMAGE_BYTES = 10.megabytes
  MAX_TAGS = 20
  MAX_TAG_LENGTH = 40
  URL_FIELDS = %i[live_url github_url].freeze

  belongs_to :user, optional: true
  has_one_attached :image
  serialize :tags, type: Array, coder: JSON

  before_validation :normalize_fields

  validates :title, presence: true
  validates :status, inclusion: { in: %w[published draft] }, allow_nil: true
  # Limits apply when a field changes so legacy rows remain editable.
  validates :title, length: { maximum: 160 }, if: :will_save_change_to_title?
  validates :description, length: { maximum: 10_000 }, allow_blank: true, if: :will_save_change_to_description?
  validates :category, length: { maximum: 80 }, allow_blank: true, if: :will_save_change_to_category?
  validates :client, length: { maximum: 160 }, allow_blank: true, if: :will_save_change_to_client?
  validates :year, length: { maximum: 20 }, allow_blank: true, if: :will_save_change_to_year?
  validates :color, length: { maximum: 40 }, allow_blank: true, if: :will_save_change_to_color?
  validates :live_url, :github_url, length: { maximum: 2048 }, allow_blank: true
  validate :urls_must_be_http, if: -> { URL_FIELDS.any? { |f| will_save_change_to_attribute?(f) } }
  validate :tags_shape, if: :will_save_change_to_tags?
  validate :image_type_and_size, if: -> { attachment_changes["image"].present? }

  scope :published, -> { where(status: "published") }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }

  # True for absolute http(s) URLs with a host. Used for live/github links that
  # are rendered as href on the public site (blocks javascript:, data:, etc.).
  def self.safe_http_url?(value)
    uri = URI.parse(value.to_s.strip)
    %w[http https].include?(uri.scheme&.downcase) && uri.host.present? && uri.userinfo.blank?
  rescue URI::InvalidURIError
    false
  end

  def image_url
    return nil unless image.attached?
    Rails.application.routes.url_helpers.rails_blob_url(image)
  end

  private

  def normalize_fields
    %i[title description category client year color live_url github_url].each do |field|
      value = self[field]
      self[field] = value.strip.presence if value.is_a?(String)
    end
    if tags.is_a?(Array)
      self.tags = tags.map { |t| t.to_s.strip }.reject(&:blank?).uniq
    end
  end

  def urls_must_be_http
    URL_FIELDS.each do |field|
      value = self[field]
      next if value.blank?
      next if self.class.safe_http_url?(value)

      errors.add(field, "must be a full http:// or https:// URL")
    end
  end

  def tags_shape
    list = Array(tags)
    errors.add(:tags, "can have at most #{MAX_TAGS} entries") if list.size > MAX_TAGS
    if list.any? { |t| t.to_s.length > MAX_TAG_LENGTH }
      errors.add(:tags, "must each be #{MAX_TAG_LENGTH} characters or fewer")
    end
  end

  def image_type_and_size
    return unless image.attached?

    blob = image.blob
    unless ALLOWED_IMAGE_TYPES.include?(blob.content_type.to_s.downcase)
      errors.add(:image, "must be a JPEG, PNG, GIF or WebP image")
    end
    if blob.byte_size.to_i > MAX_IMAGE_BYTES
      errors.add(:image, "must be 10 MB or smaller")
    end
  end
end
