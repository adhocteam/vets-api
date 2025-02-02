# frozen_string_literal: true

require 'rails_helper'
# require 'prawn'
# require 'prawn/table'
require 'lighthouse/veterans_health/client'

RSpec.describe RapidReadyForDecision::FastTrackPdfGenerator do
  subject { PDF::Inspector::Text.analyze(compiled_pdf.render).strings }

  if ENV['_SAVE_RRD_PDF_FILE']
    after do |example|
      file_name = "tmp/rrd-pdf-preview-#{example.full_description.parameterize}-#{Time.now.to_i}.pdf"
      compiled_pdf.render_file(file_name)
      puts "\n #{file_name}"
    end
  end

  let(:compiled_pdf) { pdf_generator.generate }

  let(:client) do
    # Using specific test ICN below:
    Lighthouse::VeteransHealth::Client.new(2_000_163)
  end

  let(:bp_data) { client.list_bp_observations }

  let(:parsed_bp_data) do
    # At least one of the bp readings must be from the last year
    original_first_bp_reading = bp_data.body['entry'].first
    original_first_bp_reading['resource']['effectiveDateTime'] = (DateTime.now - 2.weeks).iso8601

    RapidReadyForDecision::LighthouseObservationData.new(bp_data).transform
  end

  let(:parsed_medications_data) do
    RapidReadyForDecision::LighthouseMedicationRequestData.new(client.list_medication_requests).transform
  end

  let(:patient_name) do
    { first: 'Cat', middle: 'Marie', last: 'Power', suffix: 'Jr.', birthdate: '10-10-1968' }
  end

  let(:disability_type) { :hypertension }

  let(:pdf_generator) do
    assessed_data = {
      bp_readings: parsed_bp_data,
      medications: parsed_medications_data
    }
    RapidReadyForDecision::FastTrackPdfGenerator.new(patient_name, assessed_data, disability_type)
  end

  describe '#generate' do
    shared_examples 'includes introduction' do
      it 'includes the veterans name' do
        expect(subject).to include 'Cat Marie Power, Jr.'
      end

      it 'includes the veterans birthdate' do
        expect(subject).to include 'DOB: 10-10-1968'
      end

      context 'when veteran birthdate includes timestamp artifact' do
        let(:patient_name) do
          { first: 'Cat', middle: 'Marie', last: 'Power', suffix: 'Jr.', birthdate: '1968-10-20T00:00:00+00:00' }
        end

        it 'simplifies the format of the veterans birthdate' do
          expect(subject).to include 'DOB: 10-20-1968'
        end
      end
    end

    context 'when pdf is for hypertension' do
      let(:disability_type) { :hypertension }

      around do |example|
        VCR.use_cassette('rrd/hypertension', &example)
      end

      it_behaves_like 'includes introduction'

      it 'includes the veterans blood pressure readings' do
        expect(subject).to include 'Blood pressure: 115/87'
      end

      context 'when BP readings do not have values' do
        let(:parsed_bp_data) do
          # At least one of the bp readings must be from the last year
          original_first_bp_reading = bp_data.body['entry'].first
          original_first_bp_reading['resource']['effectiveDateTime'] = (DateTime.now - 2.weeks).iso8601

          data = RapidReadyForDecision::LighthouseObservationData.new(bp_data).transform
          data.first.delete(:systolic)
          data.first.delete(:diastolic)
          data
        end

        it 'includes the veterans blood pressure readings' do
          expect(subject).to include 'Blood pressure: (not-provided)/(not-provided)'
        end
      end

      it 'includes the veterans medications' do
        dosages = parsed_medications_data.map do |med|
          next if med['dosageInstructions'].blank?

          # renderer includes an extra space
          "#{med['dosageInstructions'].join('; ')} "
        end.compact

        expect(subject).to include(*dosages)
      end

      context 'when no medications are present' do
        let(:parsed_medications_data) { [] }

        it 'shows message when no medications are present' do
          expect(subject).to include('No active medications were found in the last year')
        end

        it 'shows the active prescriptions header even if no meds present' do
          expect(subject).to include('Active Prescriptions')
        end
      end

      context 'when medication data are nil' do
        let(:parsed_medications_data) { nil }

        it 'continues rendering with message' do
          expect(subject).to include('No active medications were found in the last year')
        end
      end
    end

    context 'when pdf is for asthma' do
      let(:disability_type) { :asthma }
      let(:parsed_bp_data) { nil }
      let(:parsed_medications_data) do
        [{ 'status' => 'active',
           'authoredOn' => '1998-02-12T02:15:52Z',
           'description' => 'Dose Inhaler',
           'notes' => ['Dose Inhaler'],
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'],
           'refills' => 12,
           'route' => 'As directed by physician.',
           'duration' => '30 days',
           :flagged => true },
         { 'status' => 'active',
           'authoredOn' => '2009-03-25T01:15:52Z',
           'description' => 'Hydrocortisone 10 MG/ML Topical Cream',
           'notes' => ['Hydrocortisone 10 MG/ML Topical Cream'],
           'dosageInstructions' => ['Once per day.', 'As directed by physician.'],
           :flagged => false }]
      end

      it_behaves_like 'includes introduction'

      context 'when potential asthma-related medication is available' do
        it 'flags potential asthma-related medication' do
          expect(subject.join).to include('▶ Dose Inhaler ◀')
          expect(subject.join).not_to include('▶ Hydrocortisone 10 MG/ML Topical Cream ◀')
        end
      end
    end
  end
end
