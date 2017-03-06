Fabricator :post do
  title { Faker::Lorem.words(rand 1..5).join ' ' }
  content { Faker::Lorem.paragraphs(rand 1..4).join '\n\n' }
  category { Category.any? ? Category.all.sample : Fabricate(:category) }
end
