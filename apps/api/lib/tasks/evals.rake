namespace :evals do
  desc "Load eval cases from fixtures/evals/<suite>.yml (SUITE=insights; default: every fixture file)"
  task load: :environment do
    suites = ENV["SUITE"] ? [ ENV["SUITE"] ] : Dir.glob(Evals::CaseLoader::FIXTURES_DIR.join("*.yml")).map { File.basename(_1, ".yml") }
    suites.each do |suite|
      cases = Evals::CaseLoader.call(suite: suite)
      puts "#{suite}: #{cases.size} cases loaded"
    end
  end
end
