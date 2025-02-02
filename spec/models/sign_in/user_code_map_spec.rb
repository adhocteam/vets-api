# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserCodeMap, type: :model do
  let(:user_code_map) do
    create(:user_code_map,
           login_code: login_code,
           type: type,
           client_state: client_state,
           client_id: client_id)
  end

  let(:login_code) { 'some-login-code' }
  let(:type) { 'some-type' }
  let(:client_state) { 'some-client-state' }
  let(:client_id) { 'some-client-id' }

  describe 'validations' do
    describe '#login_code' do
      subject { user_code_map.login_code }

      context 'when login_code is nil' do
        let(:login_code) { nil }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { "Validation failed: Login code can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when type is nil' do
        let(:type) { nil }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { "Validation failed: Type can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when client_id is nil' do
        let(:client_id) { nil }
        let(:expected_error) { ActiveModel::ValidationError }
        let(:expected_error_message) { "Validation failed: Client can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end
end
