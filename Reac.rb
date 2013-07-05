
Parents = Struct.new(:a, :b)

Operations = Struct.new(:add, :sub, :mul, :div, :mod)

Ops = Operations.new(
	Proc.new { |a, b|  a.val + b.val },
	Proc.new { |a, b|  a.val - b.val },
	Proc.new { |a, b|  a.val * b.val },
	Proc.new { |a, b|  a.val / b.val },
	Proc.new { |a, b|  a.val % b.val }
)

class Reac 

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
	end

	def onChange(proc)
		@onChange = proc
	end

	def val=(val)
		@val = val
		@children.each do |child| child.update() end #maybe pass a bool saying if this is the last child to be updated
		if @onChange then @onChange.call(@val) end
	end

	def +(other)
		op(self.val + other.val, Ops.add, other)
	end

	def -(other)
		op(self.val - other.val, Ops.sub, other)
	end

	def *(other)
		op(self.val * other.val, Ops.mul, other)
	end

	def /(other)
		op(self.val / other.val, Ops.div, other)
	end

	def %(other)
		op(self.val % other.val, Ops.mod, other)
	end

	# figure out expected behaviour on this one
	# def +=(other) end 
	
	#Internals
	#--------------------------------------------------------------------------
	protected

	def update
		self.val = @operation.call(@parents.a, @parents.b)
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

	def op(value, operator, other)
		temp = Reac.new(value, operator)
		link(temp, other)
	end

end

# Testing
# -----------------------------------------------
b = Reac.new(3.0)
c = Reac.new(4.0)

a = (b + c) #* b / c
a.onChange(Proc.new { || puts('a changed!!!') })

puts(a.val)
b.val = 4.0
puts(a.val)
c.val = 2
