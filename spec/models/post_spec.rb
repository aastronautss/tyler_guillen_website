require 'rails_helper'

describe Post do
  context 'associations' do
    it { should belong_to(:category) }
  end

  describe '.recent' do
    it 'returns 5 published Post records' do
      Fabricate.times 7, :post, date_published: Time.now
      expect(Post.recent.count).to eq(5)
    end

    it 'returns the most recent Post first' do
      post_3 = Fabricate :post, date_published: 3.days.ago
      post_1 = Fabricate :post, date_published: 1.day.ago
      post_2 = Fabricate :post, date_published: 2.days.ago

      expect(Post.recent).to eq([post_1, post_2, post_3])
    end
  end

  describe '#publish!' do
    context 'with valid fields' do
      let(:post) { Fabricate :post }

      it 'sets :date_published' do
        post.publish!
        expect(post.reload.date_published).to be_present
      end
    end

    context 'with a blank field' do
      let(:post) { Fabricate :post, title: '' }

      it 'does not set :date_published' do
        post.publish!
        expect(post.reload.date_published).to be_nil
      end

      it 'returns false' do
        expect(post.publish!).to eq(false)
      end
    end
  end
end
