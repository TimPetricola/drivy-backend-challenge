require 'json'
require 'date'

class Car
  attr_reader :id, :price_per_day, :price_per_km

  def initialize(id:, price_per_day:, price_per_km:)
    @id = id
    @price_per_day = price_per_day
    @price_per_km = price_per_km
  end
end

class Rental
  attr_reader :id, :car, :start_date, :end_date, :distance

  def initialize(id:, car:, start_date:, end_date:, distance:)
    @id = id
    @car = car
    @start_date = start_date
    @end_date = end_date
    @distance = distance
  end

  def duration
    (end_date - start_date).to_i + 1
  end

  def price
    time_price + distance_price
  end

  private

  def time_price
    duration * car.price_per_day
  end

  def distance_price
    distance * car.price_per_km
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
module Level1
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
