# frozen_string_literal: true

RSpec.describe Hanami::Mailer::Configuration do
  subject { described_class.new }

  describe '#root=' do
    describe 'when a value is given' do
      describe 'and it is a string' do
        it 'sets it as a Pathname' do
          subject.root = 'spec'
          expect(subject.root).to eq(Pathname.new('spec').realpath)
        end
      end

      describe 'and it is a pathname' do
        it 'sets it' do
          subject.root = Pathname.new('spec')
          expect(subject.root).to eq(Pathname.new('spec').realpath)
        end
      end

      describe 'and it implements #to_pathname' do
        before do
          RootPath = Struct.new(:path) do
            def to_pathname
              Pathname(path)
            end
          end
        end

        after do
          Object.send(:remove_const, :RootPath)
        end

        it 'sets the converted value' do
          subject.root = RootPath.new('spec')
          expect(subject.root).to eq(Pathname.new('spec').realpath)
        end
      end

      describe 'and it is an unexisting path' do
        it 'raises an error' do
          expect do
            subject.root = '/path/to/unknown'
          end.to raise_error(Errno::ENOENT)
        end
      end
    end

    describe 'when a value is not given' do
      it 'defaults to the current path' do
        expect(subject.root).to eq(Pathname.new('.').realpath)
      end
    end
  end

  describe '#delivery_method' do
    describe 'when not previously set' do
      it 'defaults to SMTP' do
        expect(subject.delivery_method).to eq(:smtp)
      end
    end

    describe 'set with a symbol' do
      before do
        subject.delivery_method = :exim, { location: '/path/to/exim' }
      end

      it 'saves the delivery method in the configuration' do
        expect(subject.delivery_method).to eq([:exim, { location: '/path/to/exim' }])
      end
    end

    describe 'set with a class' do
      before do
        subject.delivery_method = MandrillDeliveryMethod,
                                  { username: 'mandrill-username', password: 'mandrill-api-key' }
      end

      it 'saves the delivery method in the configuration' do
        expect(subject.delivery_method).to eq([MandrillDeliveryMethod, username: 'mandrill-username', password: 'mandrill-api-key'])
      end
    end
  end

  describe '#default_charset' do
    describe 'when not previously set' do
      it 'defaults to UTF-8' do
        expect(subject.default_charset).to eq('UTF-8')
      end
    end

    describe 'when set' do
      before do
        subject.default_charset = 'iso-8859-1'
      end

      it 'saves the delivery method in the configuration' do
        expect(subject.default_charset).to eq('iso-8859-1')
      end
    end
  end

  describe "#freeze" do
    before do
      subject.freeze
    end

    it "is frozen" do
      expect(subject).to be_frozen
    end

    it "raises error if trying to add a mailer" do
      expect { subject.add_mailer(WelcomeMailer) }.to raise_error(RuntimeError)
    end
  end
end
