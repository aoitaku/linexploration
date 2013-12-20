class TextSingle < Sprite
  attr_accessor :font
  def initialize(x, y, font)
    self.x = x
    self.y = y
    @font = font
  end
  def draw(text)
    Window.draw_font(self.x, self.y, text, @font)
  end
end
class TextSet < TextSingle
  attr_accessor :label
  def initialize(x, y, label, font)
    super(x, y, font)
    @label = label
  end
  def draw(text)
    Window.draw_font(self.x, self.y, @label, @font)
    x = self.x + font.size * (11 - text.size)
    Window.draw_font(x, self.y, text, @font)
  end
end
class TextList < TextSet
  attr_accessor :label
  def draw(texts)
    Window.draw_font(self.x, self.y, @label, @font)
    texts.each.with_index do |text, i|
      x = self.x + font.size * (5 * i + 11 - text.size)
      Window.draw_font(x, self.y, text, @font)
    end
  end
end
class ExplorationView
  def initialize(exploration, font)
    @exploration = exploration
    @font = font
    x = font.size * 7
    y = 8 + font.size
    @pos     = TextSet.new(x, y, 'POS', font)
    @depth   = TextSet.new(x + font.size * 15, y, 'DEPTH', font)
    y += font.size * 2
    @party_view = PartyView.new(x, y, exploration.party, font)
    @light = Image.new(20,20).
      circle_fill(10,10,10,[31,255,223,0]).
      circle_fill(10,10,8,[63,255,223,0]).
      circle_fill(10,10,6,[95,255,223,0]).
      circle_fill(10,10,4,[127,255,223,0])
    @image = Image.new(2,2).fill([0,127,255])
  end
  def draw
    @exploration.dungeon.points.each {|point|
      case point
      when Torchlight
        Window.draw_line(point.x, point.y-4, point.x, point.y, [255,223,0])
        Window.draw_line(point.x-1, point.y-4, point.x-1, point.y, [255,223,0])
        Window.draw(point.x-10, point.y-15, @light)
      end
    }
    @pos.draw(@exploration.party.x.to_s)
    @depth.draw(@exploration.party.frontier.to_s)
    @party_view.draw
    Window.draw(@exploration.party.x - 1, @exploration.party.y - 1, @image)
    Window.draw_line(@exploration.party.departure, 239, @exploration.party.frontier, 239, [63,63,63])
    Window.draw_line(@exploration.party.departure, 240, @exploration.party.frontier, 240, [63,63,63])
    Window.draw_font(256, 240, 'GAME OVER', @font) if @exploration.party.dead?
  end
end
class PartyView
  def initialize(x, y, party, font)
    @party = party
    @font = font
    @food    = TextSet.new(x, y, 'FOOD', font)
    @oil     = TextSet.new(x + font.size * 15, y, 'OIL', font)
    @gold    = TextSet.new(x, y + font.size, 'GOLD', font)
    @life    = TextList.new(x, y + 4 + font.size * 3, 'LIFE', font)
    @stamina = TextList.new(x, y + 4 + font.size * 4, 'STAMINA', font)
  end
  def draw
    @food.draw(@party.food.to_s)
    @oil.draw(@party.oil.to_s)
    @gold.draw((@party.gold + @party.treasure).to_s)
    @life.draw(@party.explorers.map{|explorer| explorer.life.to_s })
    @stamina.draw(@party.explorers.map{|explorer| explorer.stamina.to_s })
  end
end

class UIView
  attr_accessor :model
  def initialize(model)
    @model = model
  end
  def draw
    @model.container.render
  end
end

class IntermissionView < UIView
  InnLabel     = :'やどにとまる'
  FoodLabel    = :'しょくりょうのほじゅう'
  OilLabel     = :'ねんりょうのほじゅう'
  ExploreLabel = :'たんさくかいし!'
  Message = {
    InnLabel     => 'やどにとまります',
    FoodLabel    => 'しょくりょうをほじゅうします',
    OilLabel     => 'ねんりょうをほじゅうします',
    ExploreLabel => 'たんさくにしゅっぱつします',
  }
  Cost = {
      InnLabel     => "-200 GOLD",
      FoodLabel    => "-20 GOLD >> 1 FOOD",
      OilLabel     => "-100 GOLD >> 1 OIL",
      ExploreLabel => nil
  }
  Capacity = "さいだい %d ケ こうにゅうかのう"
  def initialize(model, font)
    super(model)
    x = font.size * 7
    y = 8 + font.size
    @score = TextSet.new(x, y, 'SCORE', font)
    y += font.size * 2
    @party_view = PartyView.new(x, y, model.party, font)
    @message    = TextSingle.new(320, 362, font)
    @cost       = TextSingle.new(320, 394, font)
    @capacity   = TextSingle.new(320, 426, font)
  end
  def draw
    super
    @score.draw(@model.party.score.to_s)
    @party_view.draw
    key = @model.container.selected_component.text.to_sym
    @message.draw(Message[key])
    @cost.draw(Cost[key]) if Cost[key]
    capacity = {
      FoodLabel    => [@model.party.max_food - @model.party.food, 0].max,
      OilLabel     => [@model.party.max_oil - @model.party.oil, 0].max,
      ExploreLabel => nil
    }[key]
    @capacity.draw(Capacity % capacity) if capacity
  end
end
