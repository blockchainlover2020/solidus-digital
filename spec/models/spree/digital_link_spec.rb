# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::DigitalLink do
  context 'validation' do
    it { is_expected.to belong_to(:digital) }
    it { is_expected.to belong_to(:line_item) }
  end

  describe "#create" do
    it "creates an appropriately long secret" do
      expect(create(:digital_link, secret: nil).secret.length).to eq(30)
    end

    it "zeroes out the access counter on creation" do
      expect(create(:digital_link, access_counter: nil).access_counter).to eq(0)
    end
  end

  describe "#update" do
    it "does not change the secret when updated" do
      digital_link = create(:digital_link)
      secret = digital_link.secret
      digital_link.increment(:access_counter).save
      expect(digital_link.secret).to eq(secret)
    end

    it "enforces to have an associated digital" do
      link = create(:digital_link)
      expect { link.update!(digital: nil) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "does not allow an empty or too short secret" do
      link = create(:digital_link)
      expect { link.update!(secret: nil) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { link.update!(secret: 'x' * 25) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "authorization" do
    let(:link) { create(:digital_link) }

    before { Spree::DigitalConfiguration.reset }

    it "increments the counter using #authorize!" do
      expect(link.access_counter).to eq(0)
      expect { link.authorize! }.to change(link, :access_counter).by(1)
    end

    it "is #authorized? when configuration for access_counter set to nil" do
      stub_spree_preferences(Spree::DigitalConfiguration, authorized_clicks: nil)
      expect(link.authorizable?).to be true
    end

    it "is not #authorized? when the access_counter is too high" do
      allow(link).to receive_messages(access_counter: Spree::DigitalConfiguration[:authorized_clicks] - 1)
      expect(link.authorizable?).to be true

      allow(link).to receive_messages(access_counter: Spree::DigitalConfiguration[:authorized_clicks])
      expect(link.authorizable?).to be false
    end

    it "is not #authorize! when the created_at date is too far in the past" do
      expect(link.authorize!).to be true

      allow(link).to receive_messages(created_at: (Spree::DigitalConfiguration[:authorized_days] * 24 - 1).hours.ago)
      expect(link.authorize!).to be true

      allow(link).to receive_messages(created_at: (Spree::DigitalConfiguration[:authorized_days] * 24 + 1).hours.ago)
      expect(link.authorize!).to be false
    end

    it "is not #authorized? when both access_counter and created_at are invalid" do
      expect(link.authorizable?).to be true
      allow(link).to receive_messages(
        access_counter: Spree::DigitalConfiguration[:authorized_clicks],
        created_at: (Spree::DigitalConfiguration[:authorized_days] * 24 + 1).hours.ago
      )
      expect(link.authorizable?).to be false
    end
  end

  describe '#reset!' do
    it 'resets the access counter' do
      link = create(:digital_link)
      link.authorize!
      expect(link.access_counter).to eq(1)

      link.reset!
      expect(link.access_counter).to eq(0)
    end
  end
end
