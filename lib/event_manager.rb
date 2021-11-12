require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'pry-byebug'

def open_csv
  CSV.open(
    'event_attendees.csv',
    headers: true,
    header_converters: :symbol
  )
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers
  csv = open_csv
  csv.each do |row|
    puts clean_phone_number(row[:homephone])
  end
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

def find_peak_registration_hours
  csv = open_csv
  registration_times = collect_registration_times(csv)
  registration_hours = []
  registration_times.each do |time|
    registration_hours.push(strptime_to_hour(time))
  end
  registration_hours.tally
end

def find_peak_registration_days
  csv = open_csv
  registration_times = collect_registration_times(csv)
  registration_days = []
  registration_times.each do |time|
    registration_days.push(strptime_to_day_of_week(time))
  end
  registration_days.tally
end

# Collect all registration times in an array
def collect_registration_times(csv)
  registration_times = []
  csv.each do |row|
    registration_times.push(row[:regdate])
  end
  registration_times
end

# Simplify all registration times to their hour.
def strptime_to_hour(time)
  Time.strptime(time, '%m/%d/%Y %k').hour
end

# Simplify all registration times to their day of week.
def strptime_to_day_of_week(time)
  Time.strptime(time, '%m/%d/%Y %k').strftime('%a')
end

# def tally_collection(arr)
#   arr.tally
# end

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
    'You can find your representatives by visiting'\
      ' www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') { |file| file.puts form_letter }
end

puts 'EventManager initialized.'

erb_template = ERB.new File.read('form_letter.erb')

open_csv.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

clean_phone_numbers
puts "Peak hours: #{find_peak_registration_hours}"
puts "Peak days: #{find_peak_registration_days}"
