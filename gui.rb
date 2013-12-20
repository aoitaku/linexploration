#!ruby
# coding: utf-8
require 'dxruby'
require 'forwardable'
class Hash
  def extract(*args)
    args.map{|k,v| self[k] or v}
  end
end
class Font
  @@cache = {}
  @@default = "ＭＳゴシック"
  def self.default
    @@default
  end
  def self.default=(default)
    @@default = default
  end
  def self.instance(size, face=Font.default, args={})
    weight, italic = args.extract(weight: false, italic: false)
    id = [size, face, weight, italic].hash
    if Font.cached?(id)
      return Font.cache(id)
    else
      font = Font.new(size, face, weight: weight, italic: italic)
      Font.store(font)
      return font
    end
  end
  def self.cache(id)
    @@cache[id]
  end
  def self.cached?(id)
    @@cache.include? id
  end
  def self.store(font)
    @@cache.store(font.id, font)
  end
  def self.delete(font)
    @@cache.delete(font.id)
  end
  def self.clear
    @@cache.clear
  end
  alias :do_dispose :dispose
  def dispose
    do_dispose unless Font.cached?(self.id)
  end
  def description
    return [self.size, self.fontname, self.weight, self.italic]
  end
  def id
    self.description.hash
  end
end
module Color
  module_function
  def alpha(color)
    if alpha?(color)
      color.first
    else
      255
    end
  end

  def alpha?(color)
    color.size == 4
  end

  def transparent?(color)
    alpha(color) == 0
  end
end

module UI
  @@component_stack = []
  module_function
  def classify(id)
    Object.const_get(id.to_s.gsub(/(?:^|_)(.)/) { $1.upcase })
  end
  def create
    module_eval(&proc)
  end
  def method_missing(id, *args)
    if block_given?
      @@component_stack.push(classify(id).new)
      module_eval(&proc)
      component = @@component_stack.pop
      if @@component_stack.empty?
        return component
      else
        @@component_stack.last.add_component(component)
      end
    else
      @@component_stack.last.__send__(:"#{id}=", *args)
    end
  end
  class Component
    extend Forwardable
    attr_accessor :x, :y, :z, :margin, :padding
    attr_reader :bgcolor, :width, :height
    def initialize
      @x, @y, @z, @margin, @padding = 0, 0, 0, 0, 0
      @bgcolor = [0,0,0,0]
      @width, @height = Window.width, Window.height
    end
    def focussed?
      false
    end
    def focussable?
      false
    end
    def selectable?
      false
    end
    def bgcolor=(color)
      @bgcolor = color
      @bg.fill(@bgcolor) if @bg
    end
    def gen_bg
      @bg = Image.new(width, height, @bgcolor)
    end
    def width=(width)
      @bg.dispose if @bg && @bg.width < width
      @width = width
    end
    def height=(height)
      @bg.dispose if @bg && @bg.height < height
      @height = height
    end
    def draw_bg
      gen_bg unless @bg
      Window.draw(
        self.x,
        self.y,
        @bg,
        self.z
      ) if Color.transparent?(self.bgcolor)
    end
  end
  module Describable
    attr_reader :font
    attr_accessor :color, :text
    attr_accessor :font_size, :font_face, :font_weight, :font_italic
    def initialize
      super
      @text = ""
      @color = [255,255,255,255]
      @font_size = 32
      @font_face = Font.default
      @font_weight = false
      @font_italic = false
      @font = Font.instance(self.font_size, self.font_face, {
        :weight => self.font_weight,
        :italic => self.font_italic
      })
    end
    def text_width
      if self.text.empty?
        self.font_size
      else
        self.font.getWidth(self.text)
      end
    end
    def line_height
      self.font_size
    end
    def font_description
      return [self.font_size, self.font_face, self.font_weight, self.font_italic]
    end
    def font=(font)
      self.font_size,
      self.font_face,
      self.font_weight,
      self.font_italic = *font.description
      @font = font
    end
    def draw_text
      @font = Font.instance(self.font_size, self.font_face, {
        :weight => self.font_weight,
        :italic => self.font_italic
      }) if self.font.description != self.font_description
      Window.drawFont(
        self.x + self.padding,
        self.y + self.padding,
        self.text,
        self.font, {
          :z => self.z,
          :color => self.color
        }
      ) unless self.text.empty?
    end
  end
  module Focussable
    attr_accessor :focus
    def initialize
      super
      @focus = false
    end
    def focussable?
      true
    end
    def focussed?
      self.focus
    end
  end
  module Controllable
    def initialize
      super
      @event_handlers = {}
      @event_handlers.default = Proc.new { false }
    end
    def selectable?
      true
    end
    def handle_event(type, code)
      event_handler(type).call(code)
    end
    def event_handler(type)
      @event_handlers[type]
    end
    def add_event_handler(type, &handler)
      @event_handlers.store(type, handler)
    end
    def delete_event_handler(type)
      @event_handlers.delete(type)
    end
  end
  module Containable
    attr_reader :components
    include Controllable
    def initialize
      super
      @index = 0
      @components = []
    end
    def handle_event(type, code)
      processed = false
      if selected_component.focussed? == false
        processed = super
      end
      if processed == false
        processed = selected_component.handle_event(type, code)
      end
      return processed
    end
    def add_component(component)
      @components.push(component)
    end
    def remove_component
      @components.remove
    end
    def delete_component(component)
      @components.delete(component)
    end
    def selectable?
      selectable_components.size > 0
    end
    def selectable_components
      @components.map {|component|
        component if component.selectable?
      }.compact
    end
    def selected_component
      selectable_components[@index]
    end
    def forward_cursor
      @index += 1
      @index = 0 if @index == selectable_components.size
    end
    def backward_cursor
      @index = selectable_components.size if @index == 0
      @index -= 1
    end
    def relayout_components
      abs_y = self.y + self.padding * 2
      @components.each {|component|
        if component.kind_of? Containable
          component.relayout_components
        else
          component.x = component.margin + self.x + self.padding
          component.y = component.margin + abs_y
        end
        abs_y += component.height + component.margin + component.padding * 2
      }
    end
    def draw_components
      for component in @components
        if component == selected_component
          if component.focussed?
            component.focussed_render
          else
            component.selected_render
          end
        else
          component.render
        end
      end
    end
  end
end
class TextLabel < UI::Component
  include UI::Describable
  def initialize
    super
    @width = 0
    @height = 0
  end
  def width
    @width > 0 ? @width : text_width
  end
  def height
    @height > 0 ? @height : line_height
  end
  def render
    draw_bg
    draw_text
  end
end
class TextButton < TextLabel
  include UI::Controllable
  def initialize
    super
  end
  def gen_selected_bg
    @selected_bg = Image.new(self.font_size, self.font_size)
    for i in 0..(self.font_size/4-1) do
      @selected_bg.boxFill(i * 2, 2 + i * 2, 1 + i * 2, self.font_size - 1 - i * 2, [255, 255, 255, 255])
    end
  end
  def selected_render
    draw_bg
    gen_selected_bg unless @selected_bg
    Window.draw(self.x - self.font_size, self.y + self.padding, @selected_bg, self.z)
    draw_text
  end
end
class Option < TextButton
  include UI::Focussable
  def initialize
    super
    @focussed_color = [255,255,255,0]
  end
  def focussed_render
    draw_bg
    Window.draw(self.x, self.y, @selected_bg, self.z)
    draw_text(@focussed_color)
  end
  def draw_text(color=self.color)
    @font = Font.instance(self.font_size, self.font_face, {
      :weight => self.font_weight,
      :italic => self.font_italic
    }) if self.font.description == self.font_description
    Window.drawFont(
      self.x + self.padding,
      self.y + self.padding,
      self.text,
      self.font, {
        :z => self.z,
        :color => color
      }
    ) unless self.text.empty?
  end
end
class Container < UI::Component
  include UI::Containable
  def render
    draw_bg
    draw_components
  end
end
