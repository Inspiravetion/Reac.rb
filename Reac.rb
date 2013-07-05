
Parents    = Struct.new(:a, :b)
Operations = Struct.new(:add, :sub, :mul, :div, :mod)

class Reac 

  #Class Variables
  #--------------------------------------------------------------------------
  Ops = Operations.new(
    Proc.new { |a, b|  a.val + b.val },
    Proc.new { |a, b|  a.val - b.val },
    Proc.new { |a, b|  a.val * b.val },
    Proc.new { |a, b|  a.val / b.val },
    Proc.new { |a, b|  a.val % b.val }
  )

  #Setup
  #--------------------------------------------------------------------------
  attr_accessor(:val)

  #API
  #--------------------------------------------------------------------------
  def initialize(val, opp = nil) 
    @val = val
    @parents = Parents.new(nil, nil)
    @operation = opp
    @onChange = nil
    @children = []
    @is_root_of_update = true
    @is_last_trace = false
  end

  def onChange(proc)
    @onChange = proc
  end

  def val=(val)
    @val = val
    @children.each_with_index do |child, i| 
      if (@is_root_of_update or @is_last_trace) and @children.last.equal? @children[i]
        then child.update(true) 
        else child.update(false) 
      end
    end
    if @is_root_of_update and @onChange then @onChange.call(@val) end
  end

  # Mutators---------------------------
  
  def +(other)
    overload_operator(self.val + other.val, Ops.add, other)
  end

  def -(other)
    overload_operator(self.val - other.val, Ops.sub, other)
  end

  def *(other)
    overload_operator(self.val * other.val, Ops.mul, other)
  end

  def /(other)
    overload_operator(self.val / other.val, Ops.div, other)
  end

  def %(other)
    overload_operator(self.val % other.val, Ops.mod, other)
  end

  # Comparison-------------------------
  
  def ==(other)
    self.val == other.val
  end

  def <=(other)
    self.val <= other.val
  end

  def >=(other)
    self.val >= other.val
  end

  def <=>(other)
    self.val <=> other.val
  end

  def <(other)
    self.val < other.val
  end

  def >(other)
    self.val > other.val
  end
  
  #Internals
  #--------------------------------------------------------------------------
  protected

  def update(last)
    @is_root_of_update = false
    if last then @is_last_trace = true end #reset 
    self.val = @operation.call(@parents.a, @parents.b)
    if last then
      if @onChange then @onChange.call(@val) end
        @is_last_trace = false
        @is_root_of_update = true
    end
  end

  def parents
    @parents
  end

  def parents=(other)
    @parents = other
  end

  def children
    @children
  end

  def children=(other)
    @children = other
  end

  #Helpers
  #--------------------------------------------------------------------------
  private 

  def link(temp, other)
    temp.parents = Parents.new(self, other)
    self.children.push(temp)
    other.children.push(temp)
    return temp
  end

  def overload_operator(value, operator, other)
    temp = Reac.new(value, operator)
    link(temp, other)
  end

end

# Testing
# -----------------------------------------------
b = Reac.new(3.0)
c = Reac.new(4.0)

a = (b + c) * b / c
a.onChange(Proc.new { || puts('a changed!!!') })

puts(a.val)
b.val = 4.0
puts(a.val)
c.val = 2
puts(a.val)
