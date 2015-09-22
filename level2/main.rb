require 'json'
require 'date'

# Initialize model with given parameters
module Model
  def initialize(params = {})
    params.each do |attr, val|
      self.public_send("#{attr}=", val)
    end

    super()
  end
end

class Car
  include Model
  attr_accessor :id, :price_per_day, :price_per_km
end

class Rental
  include Model
  attr_accessor :id, :car, :start_date, :end_date, :distance

  def duration
    (end_date - start_date).to_i + 1
  end

  def price
    Pricing.new(
      duration: duration,
      distance: distance,
      price_per_day: car.price_per_day,
      price_per_km: car.price_per_km
    ).price
  end
end

# Calculate pricing based on rental and car data
class Pricing
  include Model
  attr_accessor :duration, :distance, :price_per_day, :price_per_km

  def price
    time_price + distance_price
  end

  private

  # Time component of final price
  def time_price
    # Take time-based discounts into account
    (1..duration).reduce(0) do |price, day|
      price + (1 - discount_for_day(day)) * price_per_day
    end.to_i
  end

  # Distance component of final price
  def distance_price
    distance * price_per_km
  end

  # Return the discount to apply for given day of rental
  def discount_for_day(day)
    case day
    when 1 then 0
    when (2..4) then 0.1
    when (5..10) then 0.3
    else 0.5
    end
  end
end

# Transform raw data from a Hash into objects and keep them in memory
class DataStore
  attr_reader :cars, :rentals

  def initialize(data)
    @data = data
    initialize_cars
    initialize_rentals
  end

  private

  attr_reader :data

  def initialize_cars
    @cars = data['cars'].map do |raw|
      Car.new(
        id: raw['id'],
        price_per_day: raw['price_per_day'],
        price_per_km: raw['price_per_km']
      )
    end
  end

  def initialize_rentals
    @rentals = data['rentals'].map do |raw|
      Rental.new(
        id: raw['id'],
        car: cars.find { |car| raw['car_id'] == car.id },
        start_date: Date.parse(raw['start_date']),
        end_date: Date.parse(raw['end_date']),
        distance: raw['distance']
      )
    end
  end
end

# Non-business methods used to generate output
module Level2
  def self.output
    data = JSON.parse(File.read('data.json'))
    store = DataStore.new(data)

    JSON.pretty_generate({
      rentals: store.rentals.map do |rental|
        {
          id: rental.id,
          price: rental.price
        }
      end
    }) + "\n"
  end
end
