class Post < ApplicationRecord
  REQUIRED_FIELDS_FOR_PUBLICATION = [ :title, :content, :category ]

  belongs_to :category

  def self.recent(per_page: 5)
    where.not(date_published: nil).limit(per_page).order(date_published: :desc)
  end

  def self.published
    where.not(date_published: nil).order(date_published: :desc)
  end

  def publish!
    return false unless publishable?

    self.date_published = Time.now
    generate_blurb
    save
  end

  def published?
    self.date_published.present?
  end

  private

  def publishable?
    REQUIRED_FIELDS_FOR_PUBLICATION.all? do |field|
      send(field).present?
    end
  end

  def generate_blurb
    self.blurb = self.content.split(/\s+/).first(15).join ' '
  end
end