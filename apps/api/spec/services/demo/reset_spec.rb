require "rails_helper"

RSpec.describe Demo::Reset do
  # SPEC.md section 18's "Reset demo": visitors will try things, so one call puts
  # the deployment back to a freshly seeded Demo Factorial. The seed itself has
  # its own coverage and is slow, so it is stubbed here.
  before { allow(described_class).to receive(:seed) }

  it "removes every company with its people, policies and history, then seeds again" do
    company = create(:company)
    create(:person, company: company)
    create(:policy, company: company)

    described_class.call

    expect([ Company.count, Person.count, Policy.count ]).to eq([ 0, 0, 0 ])
    expect(described_class).to have_received(:seed)
  end

  it "signs everyone out, since the people they were are gone" do
    Session.start!(create(:person))

    described_class.call

    expect(Session.count).to eq(0)
  end

  it "purges uploaded files" do
    company = create(:company)
    company.roster_csv.attach(io: StringIO.new("Name\nAda"), filename: "roster.csv", content_type: "text/csv")

    described_class.call

    expect(ActiveStorage::Blob.count).to eq(0)
  end

  it "is only enabled when DEMO_RESET is true" do
    expect(described_class.enabled?(env: { "DEMO_RESET" => "true" })).to be(true)
    expect(described_class.enabled?(env: { "DEMO_RESET" => "false" })).to be(false)
    expect(described_class.enabled?(env: {})).to be(false)
  end
end
