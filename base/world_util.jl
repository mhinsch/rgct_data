
struct Pos
	x :: Float64
	y :: Float64
end

const Nowhere = Pos(-1.0, -1.0)


distance(p1 :: Pos, p2 :: Pos) = Util.distance(p1.x, p1.y, p2.x, p2.y)


import Base.-
(-)(a::Pos, b::Pos) = Pos(a.x - b.x, a.y - b.y)
(×)(a::Pos, b::Pos) = a.x*b.y - a.y*b.x
mid(a::Pos, b::Pos) = Pos((a.x+b.x)/2, (a.y+b.y)/2)

left_of(a, b, c) = (b-a) × (c-a) > 0

function intersect(a1, a2, b1, b2)
	(left_of(a1, a2, b1) != left_of(a1, a2, b2)) &&
		(left_of(b1, b2, a1) != left_of(b1, b2, a2))
end

contains(p1, p2, p) = p1.x <= p.x <= p2.x && p1.y <= p.y <= p2.y

