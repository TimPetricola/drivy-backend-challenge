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

  # Delegate price/fees methods to Pricing object
  %i(price insurance_fee assistance_fee drivy_fee).each do |method|
    define_method(method) do
      pricing.send(method)
    end
  end

  def duration
    (end_date - start_date).to_i + 1
  end

  private

  def pricing
    @pricing = Pricing.new(
      duration: duration,
      distance: distance,
      price_per_day: car.price_per_day,
      price_per_km: car.price_per_km
    )
  end
end

# Calculate pricing based on rental and car data
class Pricing
  COMMISSION_RATE = 0.3
  INSURANCE_FEE_RATE = 0.5
  ASSISTANCE_FEE_PER_DAY = 100

  include Model
  attr_accessor :duration, :distance, :price_per_day, :price_per_km

  def price
    time_price + distance_price
  end

  def commission
    (price * COMMISSION_RATE).to_i
  end

  def insurance_fee
    (commission * INSURANCE_FEE_RATE).to_i
  end

  def assistance_fee
    duration * ASSISTANCE_FEE_PER_DAY
  end

  def drivy_fee
    commission - insurance_fee - assistance_fee
  end

  private

  # Time component of final price
  def time_price
    (1..duration).reduce(0) do |price, day|
      price + price_for_day(day)
    end
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

  # Return the price of given day of rental
  def price_for_day(day)
    # Apply eventual discount
    (
      (1 - discount_for_day(day)) * price_per_day
    ).to_i
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
module Level3
  def self.output
    data = JSON.parse(File.read('data.json'))
    store = DataStore.new(data)

    JSON.pretty_generate({
      rentals: store.rentals.map do |rental|
        {
          id: rental.id,
          price: rental.price,
          commission: {
            insurance_fee: rental.insurance_fee,
            assistance_fee: rental.assistance_fee,
            drivy_fee: rental.drivy_fee
          }
        }
      end
    }) + "\n"
  end
end
