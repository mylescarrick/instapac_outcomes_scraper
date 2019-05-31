require 'bundler/inline'
require 'json'
require 'csv'

gemfile do
  source 'https://rubygems.org'
  gem 'typhoeus'
  gem 'nokogiri'
  gem 'rails-html-sanitizer'
end

# Maybe not needed... but helpful to not disclose our script
user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:66.0) Gecko/20100101 Firefox/66.0"
Typhoeus::Config.user_agent = user_agent

base_url = "https://educationstandards.nsw.edu.au/service/v1"

syllabuses_url = "/syllabuses"
syllabuses = JSON.parse(Typhoeus.get(base_url + syllabuses_url).body)

csv_path = "./tmp/nesa-outcomes-#{Time.now.strftime('%Y-%m-%d')}.csv"
CSV.open(csv_path, 'w', headers: true) do |csv|
  csv.to_io.write "\uFEFF" # use CSV#to_io to write BOM directly & force UTF-8

  csv << [
    'Syllabus',
    'Syllabus version',
    'Stage',
    'Objective',
    'Outcome ID',
    'Outcome description',
    'Outcome code',
    'Created at',
    'Updated at',
  ]

  # Structure is syllabuses > (fetch) syllabus > stages > objectives > outcomes
  syllabuses.each do |syllabus|
    stages_url = "/syllabuses/#{ syllabus['syllabus_id'] }/stages/with_outcomes"
    stages = JSON.parse(Typhoeus.get(base_url + stages_url).body)
    stages.each do |stage|
      objectives = stage['objectives']
      objectives.each do |objective|
        objective['outcomes'].each do |outcome|
          # description is <p>HTML</p> so needs cleaning
          clean_description = Rails::Html::FullSanitizer.new.sanitize(outcome['description'])
          csv << [
            syllabus['title'],
            syllabus['version'],
            stage['title'],
            objective['title'],
            outcome['outcome_id'],
            clean_description,
            outcome['code'],
            objective['dt_created'],
            objective['dt_lastupdated'],
          ]
        end
      end
    end
  end

end # close CSV
