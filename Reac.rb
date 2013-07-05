
Parents    = Struct.new(:a, :b)
Operations = Struct.new(:add, :sub, :mul, :div, :mod)

class Reac 

  #Class Variables
  #--------------------------------------------------------------------------
  Ops = Operations.new(
    Proc.new { |a, b|  Reac.get_value(a) + Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) - Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) * Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) / Reac.get_value(b) },
    Proc.new { |a, b|  Reac.get_value(a) % Reac.get_value(b) }
  )

  #let users define their own operation procs to use so that they can have nodes updated
  #that way
  
  #Setup
  #--------------------------------------------------------------------------
  attr_accessor(:val)

  def coerce(other)
    @coerced = true
    return [self, other]
  end

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
    @coerced = false
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
  
  # have a way for people to register how they want their defined type to be evaluated

  def +(other)
    if not other.kind_of? Reac 
      then return handle_primitive(self.val + other, Ops.add, other) 
    end
    overload_operator(self.val + other.val, Ops.add, other)
  end

  def -(other)
    if not other.kind_of? Reac 
      if @coerced then return handle_primitive(other - self.val, Ops.sub, other)
      else return handle_primitive(self.val - other, Ops.sub, other) end 
    end
    overload_operator(self.val - other.val, Ops.sub, other)
  end

  def *(other)
    overload_operator(self.val * other.val, Ops.mul, other)
  end

  def /(other)
    if not other.kind_of? Reac 
      if @coerced then return handle_primitive(other / self.val, Ops.sub, other)
      else return handle_primitive(self.val / other, Ops.sub, other) end 
    end
    overload_operator(self.val / other.val, Ops.div, other)
  end

  def %(other)
    if not other.kind_of? Reac 
      if @coerced then return handle_primitive(other % self.val, Ops.sub, other)
      else return handle_primitive(self.val % other, Ops.sub, other) end 
    end
    overload_operator(self.val % other.val, Ops.mod, other)
  end

  # Comparison-------------------------
  
  #still need to handle coerced case for this
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
    if last then @is_last_trace = true end  
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

  def link_primitive(temp, prim)
    temp.parents = @coerced ? Parents.new(prim, self) : Parents.new(self, prim)
    self.children.push(temp)
    @coerced = false
    return temp
  end

  def overload_operator(value, operation, other)
    temp = Reac.new(value, operation)
    link(temp, other)
  end

  def handle_primitive(value, operation, prim)
    temp = Reac.new(value, operation)
    link_primitive(temp, prim)
  end

  def self.get_value(obj)
    if obj.kind_of? Reac then return obj.val end
    obj
  end

end

# Testing
# -----------------------------------------------
b = Reac.new(3.0)
c = Reac.new(4.0)

a = 100 - ( (b + c) * b / c ) - 1
a.onChange(Proc.new { || puts('a changed!!!') })

puts(a.val)
b.val = 4.0
puts(a.val)
c.val = 2
puts(a.val)