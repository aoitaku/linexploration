#!ruby
# coding: utf-8
class Score
  include Comparable
  DataFile = "dat/score.dat"
  @@last = nil
  def self.setup
    if File.exist?(DataFile)
      self.load
    else
      @@scores = Array.new
    end
  end
  def self.load
    str = open(DataFile, "rb") {|f| f.read }
    @@scores = Marshal.load(str)
  end
  def self.save
    str = Marshal.dump(@@scores)
    file = open(DataFile, "w+b")
    file.write(str)
    file.close
  end
  def self.highscore
    @@scores[0]
  end
  def self.registar(score)
    @@last = score
    @@scores = @@scores.push(score).sort.reverse[0..9]
  end
  def self.data
    @@scores
  end
  def self.last
    @@last
  end
  def self.last=(last)
    @@last = last
  end
  attr_accessor :point, :depth
  def initialize(point=0, depth=0)
    @point = point
    @depth = depth
  end
  def <=>(other)
    case other
    when Score
      ret = (self.point <=> other.point)
      if ret == 0
        self.depth <=> other.depth
      else
        ret
      end
    when Numeric
      self.point <=> other
    end
  end
  def to_s
    "　" + self.point.to_s.rjust(10, "　") + "　" + self.depth.to_s.rjust(10, "　") 
  end
  def detail_info
    "　スコア" + self.to_s
  end
end
