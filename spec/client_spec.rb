require 'spec_helper'

describe Houston::Client do
  subject { Houston::Client.development }

  before(:each) do
    stub_const("Houston::Connection", MockConnection)
  end

  context '#development' do
    subject { Houston::Client.development }

    describe '#gateway_uri' do
      subject { super().gateway_uri }
      it { should == Houston::APPLE_DEVELOPMENT_GATEWAY_URI}
    end

    describe '#feedback_uri' do
      subject { super().feedback_uri }
      it { should == Houston::APPLE_DEVELOPMENT_FEEDBACK_URI}
    end
  end

  context '#production' do
    subject { Houston::Client.production }

    describe '#gateway_uri' do
      subject { super().gateway_uri }
      it { should == Houston::APPLE_PRODUCTION_GATEWAY_URI}
    end

    describe '#feedback_uri' do
      subject { super().feedback_uri }
      it { should == Houston::APPLE_PRODUCTION_FEEDBACK_URI}
    end
  end

  context '#new' do
    context 'passing options through ENV' do
      ENV['APN_GATEWAY_URI'] = "apn://gateway.example.com"
      ENV['APN_FEEDBACK_URI'] = "apn://feedback.example.com"
      ENV['APN_CERTIFICATE'] = "path/to/certificate"
      ENV['APN_CERTIFICATE_PASSPHRASE'] = "passphrase"
      ENV['APN_TIMEOUT'] = "10.0"

      subject do
        Houston::Client.new
      end

      describe '#gateway_uri' do
        subject { super().gateway_uri }
        it { should == ENV['APN_GATEWAY_URI'] }
      end

      describe '#feedback_uri' do
        subject { super().feedback_uri }
        it { should == ENV['APN_FEEDBACK_URI'] }
      end

      describe '#certificate' do
        subject { super().certificate }
        it { should == ENV['APN_CERTIFICATE'] }
      end

      describe '#passphrase' do
        subject { super().passphrase }
        it { should == ENV['APN_CERTIFICATE_PASSPHRASE'] }
      end

      describe '#timeout' do
        subject { super().timeout }
        it { should be_a(Float) }
        it { should == Float(ENV['APN_TIMEOUT']) }
      end
    end

    context 'passing options through initialize options' do
      let(:apn_gateway_uri)   { "apn://gateway.example.com" }
      let(:apn_feedback_uri)  { "apn://feedback.example.com" }
      let(:apn_cert)          { "path/to/certificate" }
      let(:apn_cert_pass)     { "passphrase" }
      let(:apn_timeout)       { "10.0" }

      subject do
        Houston::Client.new(apn_gateway_uri, apn_feedback_uri, apn_cert, apn_cert_pass, apn_timeout)
      end

      describe '#gateway_uri' do
        subject { super().gateway_uri }
        it { should == apn_gateway_uri }
      end

      describe '#feedback_uri' do
        subject { super().feedback_uri }
        it { should == apn_feedback_uri }
      end

      describe '#certificate' do
        subject { super().certificate }
        it { should == apn_cert }
      end

      describe '#passphrase' do
        subject { super().passphrase }
        it { should == apn_cert_pass }
      end

      describe '#timeout' do
        subject { super().timeout }
        it { should be_a(Float) }
        it { should == Float(apn_timeout) }
      end
    end

    describe '#push' do
      it 'should accept zero arguments' do
        expect(Houston::Client.development.push()).to be_nil()
      end
    end
  end

  describe '#unregistered_devices' do
    it 'should correctly parse the feedback response and create a dictionary of unregistered devices with timestamps' do
      subject.unregistered_devices.should == [
        {:token=>"ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969", :timestamp=>443779200},
        {:token=>"ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5970", :timestamp=>1388678223}
      ]
    end
  end

  describe '#devices' do
    it 'should correctly parse the feedback response and create an array of unregistered devices' do
      subject.devices.should == [
        "ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5969",
        "ce8be627 2e43e855 16033e24 b4c28922 0eeda487 9c477160 b2545e95 b68b5970"
      ]
    end
  end
end
