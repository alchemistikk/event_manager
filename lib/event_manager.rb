require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(number)
  number = number.tr('^0-9', '')
  if number.length < 10 || number.length > 11 || number.length == 11 && number[0] != 1
    'Bad number'
  elsif number.length == 11 && number[0] == 1
    number[1..-1]
  else
    number
  end
end

def find_peak_registration_hours(contents)
  registration_times = collect_registration_times(contents)
  tally_collection(registration_times)
end

# Collect all registration times in an array
def collect_registration_times(contents)
  registration_times = []
  contents.each do |row|
    registration_times.push(strptime_to_hour(row[1]))
  end
  registration_times
end

# Simplify all registration times to their hours.
def strptime_to_hour(time)
  DateTime.strptime(time, '%m/%d/%Y %k').hour
end

def tally_collection(arr)
  arr.tally
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  # phone_number = clean_phone_number(row[:homephone])
  # p phone_number
end

p find_peak_registration_hours(contents)
