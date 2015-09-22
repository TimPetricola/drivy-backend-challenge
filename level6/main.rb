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
  attr_accessor :id, :car, :start_date, :end_date, :distance,
                :deductible_reduction

  # Delegate price/fees methods to Pricing object
  %i(
    price deductible_reduction_price
    commission insurance_fee assistance_fee drivy_fee
  ).each do |method|
    define_method(method) do
      pricing.send(method)
    end
  end

  def price_with_options
    price + deductible_reduction_price
  end

  def duration
    (end_date - start_date).to_i + 1
  end

  private

  def pricing
    @pricing = Pricing.new(
      duration: duration,
      distance: distance,
      deductible_reduction: deductible_reduction,
      price_per_day: car.price_per_day,
      price_per_km: car.price_per_km
    )
  end
end

class RentalModification
  include Model
  attr_accessor :id, :rental, :start_date, :end_date, :distance

  def modified_rental
    @modified_rental || Rental.new(
      car: rental.car,
      start_date: start_date || rental.start_date,
      end_date: end_date || rental.end_date,
      distance: distance || rental.distance,
      deductible_reduction: rental.deductible_reduction
    )
  end
end

# Calculate pricing based on rental and car data
class Pricing
  COMMISSION_RATE = 0.3
  INSURANCE_FEE_RATE = 0.5
  ASSISTANCE_FEE_PER_DAY = 100
  DEDUCTIBLE_REDUCTION_PRICE_PER_DAY = 400

  include Model
  attr_accessor :duration, :distance, :price_per_day, :price_per_km,
                :deductible_reduction

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

  def deductible_reduction_price
    return 0 unless deductible_reduction?
    duration * DEDUCTIBLE_REDUCTION_PRICE_PER_DAY
  end

  def deductible_reduction?
    deductible_reduction
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

# Manages actions to take (who to debit/credit) for a given rental
module RentalActionsManager
  # Stores a debit/credit action
  class Action
    attr_reader :who, :type, :amount

    def initialize(who, type, amount)
      @who = who
      @type = type
      @amount = amount

      # Only deal with positive amounts
      if amount < 0
        @type = type == :credit ? :debit : :credit
        @amount = amount * -1
      end
    end
  end

  ActionType = Struct.new(:who, :type, :amount_modifier)

  ACTION_TYPES = [
    ActionType.new(:driver, :debit,
      proc { |rental| rental.price_with_options }
    ),
    ActionType.new(:owner, :credit,
      proc { |rental| rental.price - rental.commission }
    ),
    ActionType.new(:insurance, :credit,
      proc { |rental| rental.insurance_fee }
    ),
    ActionType.new(:assistance, :credit,
      proc { |rental| rental.assistance_fee }
    ),
    ActionType.new(:drivy, :credit,
      proc { |rental| rental.drivy_fee + rental.deductible_reduction_price }
    )
  ]

  def self.actions_for_rental(rental)
    # Simply return amount for given action
    generate_actions { |modifier| modifier.call(rental) }
  end

  def self.actions_for_modification(modification)
    # Return delta amount based on original and modified rental for given action
    generate_actions do |modifier|
      modifier.call(modification.modified_rental) -
      modifier.call(modification.rental)
    end
  end

  def self.generate_actions(&block)
    ACTION_TYPES.map do |type|
      Action.new(type.who, type.type, yield(type.amount_modifier))
    end
  end
end

# Transform raw data from a Hash into objects and keep them in memory
class DataStore
  attr_reader :cars, :rentals, :rental_modifications

  def initialize(data)
    @data = data
    initialize_cars
    initialize_rentals
    initialize_rental_modifications
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
        distance: raw['distance'],
        deductible_reduction: raw['deductible_reduction']
      )
    end
  end

  def initialize_rental_modifications
    @rental_modifications = data['rental_modifications'].map do |raw|
      RentalModification.new(
        id: raw['id'],
        rental: rentals.find { |rental| raw['rental_id'] == rental.id },
        start_date: raw['start_date'] && Date.parse(raw['start_date']),
        end_date: raw['end_date'] && Date.parse(raw['end_date']),
        distance: raw['distance']
      )
    end
  end
end

# Non-business methods used to generate output
module Level6
  def self.output
    data = JSON.parse(File.read('data.json'))
    store = DataStore.new(data)

    JSON.pretty_generate({
      rental_modifications: store.rental_modifications.map do |modification|
        {
          id: modification.id,
          rental_id: modification.rental.id,
          actions: RentalActionsManager.actions_for_modification(modification).map do |action|
            {
              who: action.who,
              type: action.type,
              amount: action.amount
            }
          end
        }
      end
    }) + "\n"
  end
end
