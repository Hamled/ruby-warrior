module Constants
  HEALTH = {
    :initial => 20,
    :safe => 18,
    :danger => 9
  }
  STATE_INITIAL = {
    :search_dir => :backward,
    :next_health => HEALTH[:initial]
  }
end
module Details
  def tile(dir)
    return :empty if insensate?

    tile = (dir == :forward) ? character.feel : character.feel(dir)
    case true
    when tile.enemy?
      :enemy
    when tile.ticking?
      :bomb
    when tile.captive?
      :captive
    when tile.wall?
      :wall
    when tile.stairs?
      :stairs
    else
      :empty
    end
  end
  def tile_forward
    tile(:forward)
  end
  def tile_backward
    tile(:backward)
  end
  def find(thing)
    case thing
    when tile_forward
      :forward
    when tile_backward
      :backward
    else
      nil
    end
  end
end
module Character
  module Attributes
    attr_reader :character

    def health
      if immortal?
        Constants::HEALTH[:initial]
      else
        character.health
      end
    end
    def last_health
      state[:last_health]
    end
    def search_dir
      state[:search_dir]
    end
    def insensate?
      !character.respond_to?(:feel)
    end
    def immortal?
      !character.respond_to?(:health)
    end
    def update_state(character)
        @character = character
        @turn ||= 0
        @turn += 1

        # Update our state based on the new character info
        state.merge!({
          :last_health => state[:next_health],
          :next_health => health,
          :search_dir => (insensate? || find(:wall) == :backward) ? :forward : state[:search_dir]
        })
    end
    def state
      @state ||= Constants::STATE_INITIAL
    end
  end
  module Actions
    def action!(action, dir = nil)
      action = (action.to_s + "!").to_sym
      if dir == :forward || dir.nil?
        character.send(action)
      else
        character.send(action, dir)
      end
    end
    def rest!
      action!(:rest)
    end
    def walk!(dir = :forward)
      action!(:walk, dir)
    end
    def search!
      if dir = can_attack?
        attack!(dir) # Give 'em what for
      elsif dir = can_rescue?
        rescue!(dir) # No case too big, no case too small
      else
        walk!(search_dir)
      end
    end
    def retreat!
      walk!(:backward)
    end
    def attack!(dir)
      action!(:attack, dir)
    end
    def rescue!(dir)
      action!(:rescue, dir)
    end
    def charge!
      walk!
    end
  end
  module Status
    def can_attack?
      find(:enemy)
    end
    def can_rescue?
      find(:captive)
    end
    def should_charge?
      !can_attack?
    end
    def should_retreat?
      must_rest?
    end
    def should_rest?
      health < Constants::HEALTH[:safe]
    end
    def must_rest?
      health < Constants::HEALTH[:danger]
    end
    def under_attack?
      health < last_health
    end
  end
end

class Player
  include Constants
  include Details
  include Character::Attributes
  include Character::Actions
  include Character::Status

  def play_turn(warrior)
    update_state(warrior)

    # If we're not under attack...
    if !under_attack?
      # ... then we should rest...
      return rest! if should_rest?
      # ... or search for stuff to do.
      return search!
    end

    # We've been attacked!
    if should_retreat?
      return retreat! # Fall back to rest
    elsif should_charge?
      return charge! # Find the enemy
    elsif dir = can_attack?
      return attack!(dir) # Obliterate
    end
  end
end
