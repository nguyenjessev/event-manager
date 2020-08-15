# frozen-string-literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def validate_phone(phone)
  phone = phone.to_s.delete('^0-9')

  if phone.length == 11 && phone[0] == '1'
    phone = phone.slice(1..-1)
  elsif phone.length < 10 || phone.length > 11
    phone = 'Invalid phone number.'
  end

  phone
end

def reg_hour(reg_date)
  DateTime.strptime(reg_date, '%D %R').hour
end

def reg_day(reg_date)
  DateTime.strptime(reg_date, '%D %R').wday
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
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

def best_hours(reg_hours)
  most_regs = reg_hours.values.max
  reg_hours.select { |_k, v| v == most_regs }.keys
end

def best_days(reg_days)
  most_regs = reg_days.values.max
  reg_days.select { |_k, v| v == most_regs }.keys
end

puts 'EventManager Initialized!'

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)
reg_hours = Hash.new(0)
reg_days = Hash.new(0)

contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)
contents.each do |row|
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  reg_hour = reg_hour(row[:regdate])
  reg_day = reg_day(row[:regdate])

  form_letter = erb_template.result(binding)

  save_thank_you_letter(row[0], form_letter)

  reg_hours[reg_hour] += 1
  reg_days[reg_day] += 1
end

best_hours = best_hours(reg_hours)
best_days = best_days(reg_days)
puts "Best hour(s) to advertise: #{best_hours.join(', ')}"
puts "Best day(s) to advertise: #{best_days.join(', ')}"
