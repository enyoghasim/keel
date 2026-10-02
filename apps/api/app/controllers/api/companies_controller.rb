module Api
  # Creates a company from a roster CSV and (optionally) a handbook PDF,
  # both uploaded beforehand via Active Storage direct upload and referenced
  # here by signed_id, then kicks off AssembleJob (SPEC.md section 6).
  class CompaniesController < ApplicationController
    def create
      if company_params[:roster_csv].blank?
        return render_error(message: "roster_csv is required", errors: [ "roster_csv is required" ])
      end

      company = Company.new(name: company_params[:name])

      ActiveRecord::Base.transaction do
        company.save!
        company.roster_csv.attach(company_params[:roster_csv])
        attach_handbook(company, company_params[:handbook]) if company_params[:handbook].present?
      end

      AssembleJob.perform_later(company.id)
      render_success(data: serialize(company), message: "Company created; assembling.", status: :created)
    rescue ActiveRecord::RecordInvalid => e
      render_error(message: e.message, errors: e.record.errors.full_messages)
    end

    def show
      render_success(data: serialize(Company.find(params[:id])))
    end

    private

    def attach_handbook(company, signed_id)
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      document = company.source_documents.create!(filename: blob.filename.to_s, kind: "handbook")
      document.file.attach(signed_id)
    end

    def company_params
      params.require(:company).permit(:name, :roster_csv, :handbook)
    end

    def serialize(company)
      company.as_json(only: %i[id name locale assemble_completed_stages created_at])
    end
  end
end
